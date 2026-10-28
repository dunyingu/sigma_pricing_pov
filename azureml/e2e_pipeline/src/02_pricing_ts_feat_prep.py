#import os
import logging
import argparse

import Config

#import snowflake.connector
import snowflake.snowpark
from snowflake.snowpark.session import Session
import pandas as pd


from snowflake.snowpark import types as T
from snowflake.snowpark.types import IntegerType, StringType, StructType, FloatType

from snowflake.snowpark import Window

import snowflake.snowpark.functions as F
from snowflake.snowpark.functions import udf,udtf,sproc




def ts_store_summ_feat (session,base_feat_table_name,customer_col,product_col,date_col,feat_cols_list,look_back_window_length,n_window):
    
    input_snowpark_df = session.table(base_feat_table_name)
    partition_cols = (F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"'),F.col(f'\"{date_col}\"'))
    feat_cols = tuple([F.col(f'\"{col}\"') for col in feat_cols_list])
    select_cols = partition_cols + feat_cols
    output_snowpark_df = input_snowpark_df.select(select_cols)

    windowSpec = Window.partition_by(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"')).order_by(F.col(f'\"{date_col}\"').asc())
    
    for i in range(n_window):
        look_back_period = look_back_window_length * (i+1)
        windowRows = windowSpec.rowsBetween(-look_back_period, -1)
        for col in feat_cols_list:
            output_snowpark_df = output_snowpark_df.withColumn(f'\"{col}_P{look_back_period}_Sum\"',F.sum(F.col(f'\"{col}\"')).over(windowRows))
        
        output_snowpark_df = output_snowpark_df.withColumn(f'\"P{look_back_period}_Store_Level4_Sales_Amount_Total_Percent\"',F.when(F.col(f'\"Monthly_Store_Total_Sales_Amount_P{look_back_period}_Sum\"')>0,F.round(100*F.col(f'\"Monthly_Store_Level4_Sales_Amount_P{look_back_period}_Sum\"')/F.col(f'\"Monthly_Store_Total_Sales_Amount_P{look_back_period}_Sum\"'),4)))
        output_snowpark_df = output_snowpark_df.withColumn(f'\"P{look_back_period}_Store_Product_Sales_Amount_Level4_Percent\"',F.when(F.col(f'\"Monthly_Store_Level4_Sales_Amount_P{look_back_period}_Sum\"')>0,F.round(100*F.col(f'\"Monthly_Store_Product_Sales_Amount_P{look_back_period}_Sum\"')/F.col(f'\"Monthly_Store_Level4_Sales_Amount_P{look_back_period}_Sum\"'),4)))
        output_snowpark_df = output_snowpark_df.withColumn(f'\"P{look_back_period}_Store_Product_Sales_Amount_Total_Percent\"',F.when(F.col(f'\"Monthly_Store_Total_Sales_Amount_P{look_back_period}_Sum\"')>0,F.round(100*F.col(f'\"Monthly_Store_Product_Sales_Amount_P{look_back_period}_Sum\"')/F.col(f'\"Monthly_Store_Total_Sales_Amount_P{look_back_period}_Sum\"'),4)))
        output_snowpark_df = output_snowpark_df.withColumn(f'\"P{look_back_period}_Store_Product_Promotion_Sales_Amount_Percent\"',F.when(F.col(f'\"Monthly_Store_Product_Sales_Amount_P{look_back_period}_Sum\"')>0,F.round(100*F.col(f'\"Monthly_Store_Product_Promotion_Sales_Amount_P{look_back_period}_Sum\"')/F.col(f'\"Monthly_Store_Product_Sales_Amount_P{look_back_period}_Sum\"'),4)))
        output_snowpark_df = output_snowpark_df.withColumn(f'\"P{look_back_period}_Store_Product_Promotion_Discount_Amount_Percent\"',F.when(F.col(f'\"Monthly_Store_Product_Sales_Amount_P{look_back_period}_Sum\"')>0,F.round(100*F.col(f'\"Monthly_Store_Product_Promotion_Discount_Amount_P{look_back_period}_Sum\"')/F.col(f'\"Monthly_Store_Product_Sales_Amount_P{look_back_period}_Sum\"'),4)))
        
        output_snowpark_df = output_snowpark_df.withColumn(f'\"P{look_back_period}_Store_Level4_Order_Quantity_Total_Percent\"',F.when(F.col(f'\"Monthly_Store_Total_Order_Quantity_P{look_back_period}_Sum\"')>0,F.round(100*F.col(f'\"Monthly_Store_Level4_Order_Quantity_P{look_back_period}_Sum\"')/F.col(f'\"Monthly_Store_Total_Order_Quantity_P{look_back_period}_Sum\"'),4)))
        output_snowpark_df = output_snowpark_df.withColumn(f'\"P{look_back_period}_Store_Product_Order_Quantity_Level4_Percent\"',F.when(F.col(f'\"Monthly_Store_Level4_Order_Quantity_P{look_back_period}_Sum\"')>0,F.round(100*F.col(f'\"Monthly_Store_Product_Order_Quantity_P{look_back_period}_Sum\"')/F.col(f'\"Monthly_Store_Level4_Order_Quantity_P{look_back_period}_Sum\"'),4)))
        output_snowpark_df = output_snowpark_df.withColumn(f'\"P{look_back_period}_Store_Product_Order_Quantity_Total_Percent\"',F.when(F.col(f'\"Monthly_Store_Total_Order_Quantity_P{look_back_period}_Sum\"')>0,F.round(100*F.col(f'\"Monthly_Store_Product_Order_Quantity_P{look_back_period}_Sum\"')/F.col(f'\"Monthly_Store_Total_Order_Quantity_P{look_back_period}_Sum\"'),4)))
        output_snowpark_df = output_snowpark_df.withColumn(f'\"P{look_back_period}_Store_Product_Compliance\"',F.when(F.col(f'\"Monthly_Store_Product_Order_Quantity_P{look_back_period}_Sum\"')>0,F.round(100*F.col(f'\"Monthly_Store_Product_Sigma_Order_Quantity_P{look_back_period}_Sum\"')/F.col(f'\"Monthly_Store_Product_Order_Quantity_P{look_back_period}_Sum\"'),2)))
    
    return output_snowpark_df


def ts_lag_summ (session,
                 base_feat_table_name,customer_col,product_col,date_col,derive_col,
                 look_back_window_length,n_window,velocity=True,
                 nonzero=True):
    
    input_snowpark_df = session.table(base_feat_table_name)
    output_snowpark_df = input_snowpark_df.select(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"'),F.col(f'\"{date_col}\"'),F.col(f'\"{derive_col}\"'))

    windowSpec = Window.partition_by(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"')).order_by(F.col(f'\"{date_col}\"').asc())

    total_look_back_lag = look_back_window_length * n_window
    
    for i in range(total_look_back_lag):
        lag_n = i+1 
        output_snowpark_df = output_snowpark_df.withColumn(f'\"{derive_col}_L{lag_n}\"',F.lag(F.col(f'\"{derive_col}\"'), lag_n).over(windowSpec))
    
    if velocity:
        output_snowpark_df = output_snowpark_df.withColumn(f'\"{derive_col}_P1_Velocity\"',F.col(f'\"{derive_col}\"')-F.col(f'\"{derive_col}_L1\"'))
        output_snowpark_df = output_snowpark_df.withColumn(f'\"{derive_col}_P1_Index\"',F.when((F.col(f'\"{derive_col}_L1\"')>0), F.round(100*(F.col(f'\"{derive_col}\"')-F.col(f'\"{derive_col}_L1\"'))/F.col(f'\"{derive_col}_L1\"'),1)) \
                                                           .when((F.col(f'\"{derive_col}_L1\"')==0) & (F.col(f'\"{derive_col}\"')==0), F.lit(0)) \
                                                           .when((F.col(f'\"{derive_col}_L1\"').is_null()) | (F.col(f'\"{derive_col}\"').is_null()), None).otherwise(F.lit(10000)) \
                                                           )

        for e in range(look_back_window_length):
            lag_n = e+1
            output_snowpark_df = output_snowpark_df.withColumn(f'\"{derive_col}_P1_Velocity_L{lag_n}\"',F.lag(F.col(f'\"{derive_col}_P1_Velocity\"'), lag_n).over(windowSpec))
            output_snowpark_df = output_snowpark_df.withColumn(f'\"{derive_col}_P1_Index_L{lag_n}\"',F.lag(F.col(f'\"{derive_col}_P1_Index\"'), lag_n).over(windowSpec))

    
    for j in range(n_window):
        look_back_period = look_back_window_length * (j+1)
        windowRows = windowSpec.rowsBetween(-look_back_period, -1)
        output_snowpark_df = output_snowpark_df.withColumn(f'\"{derive_col}_P{look_back_period}_Sum\"',F.sum(F.col(f'\"{derive_col}\"')).over(windowRows)) \
                                                .withColumn(f'\"{derive_col}_P{look_back_period}_Avg\"',F.avg(F.col(f'\"{derive_col}\"')).over(windowRows)) \
                                                .withColumn(f'\"{derive_col}_P{look_back_period}_Max\"',F.max(F.col(f'\"{derive_col}\"')).over(windowRows)) \
                                                .withColumn(f'\"{derive_col}_P{look_back_period}_Min\"',F.min(F.col(f'\"{derive_col}\"')).over(windowRows)) \
                                                .withColumn(f'\"{derive_col}_P{look_back_period}_Stddev\"',F.stddev(F.col(f'\"{derive_col}\"')).over(windowRows)) \
                                                .withColumn(f'\"{derive_col}_P{look_back_period}_Count_Zero\"',F.count(F.when(F.col(f'\"{derive_col}\"')>0,None).otherwise(F.col(f'\"{derive_col}\"'))).over(windowRows))
        
        if nonzero:
            output_snowpark_df = output_snowpark_df.withColumn(f'\"{derive_col}_P{look_back_period}_Non_Zero_Avg\"',F.avg(F.when(F.col(f'\"{derive_col}\"')>0,F.col(f'\"{derive_col}\"')).otherwise(None)).over(windowRows)) \
                                                    .withColumn(f'\"{derive_col}_P{look_back_period}_Non_Zero_Min\"',F.min(F.when(F.col(f'\"{derive_col}\"')>0,F.col(f'\"{derive_col}\"')).otherwise(None)).over(windowRows)) \
                                                    .withColumn(f'\"{derive_col}_P{look_back_period}_Non_Zero_Stddev\"',F.stddev(F.when(F.col(f'\"{derive_col}\"')>0,F.col(f'\"{derive_col}\"')).otherwise(None)).over(windowRows))
        

    return output_snowpark_df


def ts_window_velocity (session,
                        ts_summ_snowpark_df,customer_col,product_col,date_col,derive_col,
                        look_back_window_length,n_window,n_window_lag):
    
    windowSpec = Window.partition_by(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"')).order_by(F.col(f'\"{date_col}\"').asc())
    
    for j in range(n_window):
        look_back_period = look_back_window_length * (j+1)
        for e in range(n_window_lag):
            lag_n = e+1
            
            ts_summ_snowpark_df = ts_summ_snowpark_df.withColumn(f'\"{derive_col}_P{look_back_period}_Sum_L{lag_n}\"',F.lag(F.col(f'\"{derive_col}_P{look_back_period}_Sum\"'), lag_n).over(windowSpec)) \
                                                     .withColumn(f'\"{derive_col}_P{look_back_period}_Avg_L{lag_n}\"',F.lag(F.col(f'\"{derive_col}_P{look_back_period}_Avg\"'), lag_n).over(windowSpec)) \
                                                     .withColumn(f'\"{derive_col}_P{look_back_period}_Max_L{lag_n}\"',F.lag(F.col(f'\"{derive_col}_P{look_back_period}_Max\"'), lag_n).over(windowSpec)) \
                                                     .withColumn(f'\"{derive_col}_P{look_back_period}_Min_L{lag_n}\"',F.lag(F.col(f'\"{derive_col}_P{look_back_period}_Min\"'), lag_n).over(windowSpec)) \
                                                     .withColumn(f'\"{derive_col}_P{look_back_period}_Stddev_L{lag_n}\"',F.lag(F.col(f'\"{derive_col}_P{look_back_period}_Stddev\"'), lag_n).over(windowSpec))
        
        ts_summ_snowpark_df = ts_summ_snowpark_df.withColumn(f'\"{derive_col}_P{look_back_period}_Velocity\"',F.col(f'\"{derive_col}_P{look_back_period}_Sum\"')-F.col(f'\"{derive_col}_P{look_back_period}_Sum_L1\"'))
        ts_summ_snowpark_df = ts_summ_snowpark_df.withColumn(f'\"{derive_col}_P{look_back_period}_Index\"',F.when(F.col(f'\"{derive_col}_P{look_back_period}_Sum_L1\"')>0,F.round(100*(F.col(f'\"{derive_col}_P{look_back_period}_Sum\"')-F.col(f'\"{derive_col}_P{look_back_period}_Sum_L1\"'))/F.col(f'\"{derive_col}_P{look_back_period}_Sum_L1\"'),1)) \
                                                                                                            .when((F.col(f'\"{derive_col}_P{look_back_period}_Sum\"')==0) & (F.col(f'\"{derive_col}_P{look_back_period}_Sum_L1\"')==0), F.lit(0)) \
                                                                                                            .when((F.col(f'\"{derive_col}_P{look_back_period}_Sum\"').is_null()) | (F.col(f'\"{derive_col}_P{look_back_period}_Sum_L1\"').is_null()), None).otherwise(F.lit(10000)) \
                                                                                                            )
    

    for j in range(n_window):
        look_back_period = look_back_window_length * (j+1)
        for i in range(n_window_lag):
            lag_n = i+1
            ts_summ_snowpark_df = ts_summ_snowpark_df.withColumn(f'\"{derive_col}_P{look_back_period}_Velocity_L{lag_n}\"',F.lag(F.col(f'\"{derive_col}_P{look_back_period}_Velocity\"'), lag_n).over(windowSpec))
            ts_summ_snowpark_df = ts_summ_snowpark_df.withColumn(f'\"{derive_col}_P{look_back_period}_Index_L{lag_n}\"',F.lag(F.col(f'\"{derive_col}_P{look_back_period}_Index\"'), lag_n).over(windowSpec))
            
    return ts_summ_snowpark_df


def ts_ipi (session,
            base_feat_table_name,customer_col,product_col,date_col,order_qty_col,
            look_back_window_length,n_window,ipi_window,n_window_lag):
    
    input_snowpark_df = session.table(base_feat_table_name)
    output_snowpark_df = input_snowpark_df.select(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"'),F.col(f'\"{date_col}\"'),F.col(f'\"{order_qty_col}\"'))

    output_snowpark_df = output_snowpark_df.withColumn('\"Order_Month_Start_Date\"',F.when(F.col(f'\"{order_qty_col}\"')>0,F.col(f'\"{date_col}\"')).otherwise(None))
    output_snowpark_df = output_snowpark_df.withColumn('\"Zero_Month_Start_Date\"',F.when(F.col(f'\"{order_qty_col}\"')<=0,F.col(f'\"{date_col}\"')).otherwise(None))

    windowSpec = Window.partition_by(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"')).order_by(F.col(f'\"{date_col}\"').asc())

    for j in range(n_window):
        look_back_period = look_back_window_length * (j+1)
        windowRows = windowSpec.rowsBetween(-look_back_period, -1)

        output_snowpark_df = output_snowpark_df.withColumn(f'\"Order_P{look_back_period}_Previous\"',F.last_value(F.col('\"Order_Month_Start_Date\"'),ignore_nulls=True).over(windowRows))
        output_snowpark_df = output_snowpark_df.withColumn(f'\"Order_P{look_back_period}_IPI\"',F.datediff('Month',F.col(f'\"Order_P{look_back_period}_Previous\"'),F.col('\"Order_Month_Start_Date\"')))

        output_snowpark_df = output_snowpark_df.withColumn(f'\"Order_P{look_back_period}_IPI_Avg\"',F.avg(F.col(f'\"Order_P{look_back_period}_IPI\"')).over(windowRows)) \
                                               .withColumn(f'\"Order_P{look_back_period}_IPI_Max\"',F.max(F.col(f'\"Order_P{look_back_period}_IPI\"')).over(windowRows)) \
                                               .withColumn(f'\"Order_P{look_back_period}_IPI_Min\"',F.min(F.col(f'\"Order_P{look_back_period}_IPI\"')).over(windowRows)) \
                                               .withColumn(f'\"Order_P{look_back_period}_IPI_Stddev\"',F.stddev(F.col(f'\"Order_P{look_back_period}_IPI\"')).over(windowRows))
    
    total_look_back_lag = look_back_window_length * n_window
    windowRows = windowSpec.rowsBetween(-total_look_back_lag, -1)
    output_snowpark_df = output_snowpark_df.withColumn(f'\"P{total_look_back_lag}_Latest_Order\"',F.max(F.col('\"Order_Month_Start_Date\"')).over(windowRows))
    output_snowpark_df = output_snowpark_df.withColumn(f'\"Months_from_P{total_look_back_lag}_Latest_Order\"',F.datediff('Month',F.col(f'\"P{total_look_back_lag}_Latest_Order\"'),F.col('\"Month_Start_Date\"')))
    output_snowpark_df = output_snowpark_df.withColumn(f'\"P{total_look_back_lag}_Latest_NonZero_Order_Quantity\"',F.last_value((F.when(F.col(f'\"{order_qty_col}\"')>0,F.col(f'\"{order_qty_col}\"')).otherwise(None)),ignore_nulls=True).over(windowRows))

    output_snowpark_df = output_snowpark_df.withColumn(f'\"P{total_look_back_lag}_Latest_Zero\"',F.max(F.col('\"Zero_Month_Start_Date\"')).over(windowRows))
    output_snowpark_df = output_snowpark_df.withColumn(f'\"Months_from_P{total_look_back_lag}_Latest_Zero\"',F.datediff('Month',F.col(f'\"P{total_look_back_lag}_Latest_Zero\"'),F.col('\"Month_Start_Date\"')))
    
    
    ipi_look_back_period = look_back_window_length * ipi_window
    for e in range(n_window_lag):
        lag_n = e+1
        output_snowpark_df = output_snowpark_df.withColumn(f'\"Order_P{ipi_look_back_period}_IPI_Avg_L{lag_n}\"',F.lag(F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg\"'),lag_n).over(windowSpec)) \
                                               .withColumn(f'\"Order_P{ipi_look_back_period}_IPI_Max_L{lag_n}\"',F.lag(F.col(f'\"Order_P{ipi_look_back_period}_IPI_Max\"'),lag_n).over(windowSpec)) \
                                               .withColumn(f'\"Order_P{ipi_look_back_period}_IPI_Min_L{lag_n}\"',F.lag(F.col(f'\"Order_P{ipi_look_back_period}_IPI_Min\"'),lag_n).over(windowSpec)) \
                                               .withColumn(f'\"Order_P{ipi_look_back_period}_IPI_Stddev_L{lag_n}\"',F.lag(F.col(f'\"Order_P{ipi_look_back_period}_IPI_Stddev\"'),lag_n).over(windowSpec))

        output_snowpark_df = output_snowpark_df.withColumn(f'\"Months_from_P{total_look_back_lag}_Latest_Order_L{lag_n}\"',F.lag(F.col(f'\"Months_from_P{total_look_back_lag}_Latest_Order\"'),lag_n).over(windowSpec)) \
                                               .withColumn(f'\"P{total_look_back_lag}_Latest_NonZero_Order_Quantity_L{lag_n}\"',F.lag(F.col(f'\"P{total_look_back_lag}_Latest_NonZero_Order_Quantity\"'),lag_n).over(windowSpec)) \
                                               .withColumn(f'\"Months_from_P{total_look_back_lag}_Latest_Zero_L{lag_n}\"',F.lag(F.col(f'\"Months_from_P{total_look_back_lag}_Latest_Zero\"'),lag_n).over(windowSpec))
    
    output_snowpark_df = output_snowpark_df.withColumn(f'\"Order_P{ipi_look_back_period}_IPI_Velocity\"',F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg\"')-F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg_L1\"'))
    output_snowpark_df = output_snowpark_df.withColumn(f'\"Order_P{ipi_look_back_period}_IPI_Index\"',F.when(F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg_L1\"')>0,F.round(100*(F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg\"')-F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg_L1\"'))/F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg_L1\"'),1)) \
                                                                                                       .when((F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg\"')==0) & (F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg_L1\"')==0), F.lit(0)) \
                                                                                                       .when((F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg\"').is_null()) | (F.col(f'\"Order_P{ipi_look_back_period}_IPI_Avg_L1\"').is_null()),None).otherwise(F.lit(10000)) \
                                                                                                       )
    
    for i in range(n_window_lag):
        lag_n = i+1
        output_snowpark_df = output_snowpark_df.withColumn(f'\"Order_P{ipi_look_back_period}_IPI_Velocity_L{lag_n}\"',F.lag(F.col(f'\"Order_P{ipi_look_back_period}_IPI_Velocity\"'),lag_n).over(windowSpec))
        output_snowpark_df = output_snowpark_df.withColumn(f'\"Order_P{ipi_look_back_period}_IPI_Index_L{lag_n}\"',F.lag(F.col(f'\"Order_P{ipi_look_back_period}_IPI_Index\"'),lag_n).over(windowSpec))
    
    return output_snowpark_df


def main():

    parser = argparse.ArgumentParser()
    parser.add_argument("--sf_database", type=str, help="snowflake database")
    parser.add_argument("--sf_schema", type=str, help="snowflake database schema")
    parser.add_argument("--sf_input_table", type=str, help="snowflake input table")
    parser.add_argument("--sf_output_table", type=str, help="snowflake output table")

    args = parser.parse_args()

    logger = logging.getLogger('prcing_ts_feat_snowpark')
    format = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
    handler=logging.StreamHandler()
    handler.setFormatter(format)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

    logger.info('set up Snowflake session for the feature preparation job')
    session = Config.get_sf_session(KeyVault=Config.KeyVault)
    session.use_database(args.sf_database) #"edp_analytics_sandpit"
    session.use_schema(args.sf_schema) #"WRK"

    logger.info("define pricing base feature table name and partition keys")
    base_feat_table_name=args.sf_input_table #"BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT"
    customer_col = "Store_Code"
    product_col= "Product_Code"
    date_col = "Month_Start_Date"
    
    logger.info('create summarized store transaction features')
    feat_cols_list = ["Monthly_Store_Visit_Cnt","Monthly_Store_Total_Sales_Amount",
                     "Monthly_Store_Level4_Sales_Amount",
                     "Monthly_Store_Product_Promotion_Discount_Amount","Monthly_Store_Product_Promotion_Sales_Amount","Monthly_Store_Product_Sales_Amount",
                     "Monthly_Store_Total_Order_Quantity",
                     "Monthly_Store_Level4_Order_Quantity",
                     "Monthly_Store_Product_Sigma_Order_Quantity","Monthly_Store_Product_NonSigma_Order_Quantity","Monthly_Store_Product_Order_Quantity"
                     ]
    sp_df_store_summ = ts_store_summ_feat (session=session,
                                          base_feat_table_name=base_feat_table_name,
                                          customer_col=customer_col,product_col=product_col,date_col=date_col,
                                          feat_cols_list=feat_cols_list,look_back_window_length=3,n_window=4)

    sp_df_store_summ_feat = sp_df_store_summ.select(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"'),F.col(f'\"{date_col}\"'),
                                                    F.col('\"Monthly_Store_Visit_Cnt_P12_Sum\"'),F.col('\"Monthly_Store_Total_Sales_Amount_P12_Sum\"'),
                                                    F.col('\"Monthly_Store_Level4_Sales_Amount_P12_Sum\"'),F.col('\"Monthly_Store_Product_Sales_Amount_P12_Sum\"'),
                                                    F.col('\"Monthly_Store_Product_Promotion_Sales_Amount_P12_Sum\"'),F.col('\"Monthly_Store_Product_Promotion_Discount_Amount_P12_Sum\"'),
                                                    F.col('\"P12_Store_Level4_Sales_Amount_Total_Percent\"'),F.col('\"P12_Store_Product_Sales_Amount_Level4_Percent\"'),F.col('\"P12_Store_Product_Sales_Amount_Total_Percent\"'),
                                                    F.col('\"P12_Store_Product_Promotion_Sales_Amount_Percent\"'),F.col('\"P12_Store_Product_Promotion_Discount_Amount_Percent\"'),
                                                    F.col('\"Monthly_Store_Total_Order_Quantity_P12_Sum\"'),
                                                    F.col('\"P12_Store_Level4_Order_Quantity_Total_Percent\"'),F.col('\"P12_Store_Product_Order_Quantity_Level4_Percent\"'),F.col('\"P12_Store_Product_Order_Quantity_Total_Percent\"'),
                                                    F.col('\"P12_Store_Product_Compliance\"'),F.col('\"P9_Store_Product_Compliance\"'),F.col('\"P6_Store_Product_Compliance\"'),F.col('\"P3_Store_Product_Compliance\"')
                                                    )

    
    derive_col="Monthly_Store_Product_Order_Quantity_Log"
    logger.info(f'create time series lag, window velocity change and order interval features for the target variable - \"{derive_col}\"')
    sp_df_order_qty_lag_summ = ts_lag_summ (session=session,
                                            base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                            derive_col=derive_col,
                                            look_back_window_length=3,n_window=4,
                                            velocity=True,nonzero=True)

    sp_df_order_qty_lag_summ_feat = sp_df_order_qty_lag_summ.drop(f'\"{derive_col}\"'
                                                                 ,f'\"{derive_col}_P1_Velocity\"'
                                                                 ,f'\"{derive_col}_P1_Index\"'
                                                                 #,f'\"{derive_col}_P12_Sum\"'
                                                                 )
    
    sp_df_order_qty_lag_summ_velocity_feat = ts_window_velocity (session=session,
                                                                 ts_summ_snowpark_df=sp_df_order_qty_lag_summ_feat,
                                                                 customer_col=customer_col,product_col=product_col,date_col=date_col,derive_col=derive_col,
                                                                 look_back_window_length=3,n_window=2,n_window_lag=4)

    sp_df_order_qty_ipi = ts_ipi (session=session,
                                  base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                  order_qty_col=derive_col,
                                  look_back_window_length=3,n_window=4,ipi_window=2,n_window_lag=4)

    sp_df_order_qty_ipi_feat = sp_df_order_qty_ipi.select(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"'),F.col(f'\"{date_col}\"'),
                                                         #F.col(f'\"{derive_col}\"'),
                                                          F.col('\"Order_P6_IPI_Avg\"'),F.col('\"Order_P12_IPI_Avg\"'),
                                                          F.col('\"Order_P6_IPI_Max\"'),F.col('\"Order_P12_IPI_Max\"'),
                                                          F.col('\"Order_P6_IPI_Min\"'),F.col('\"Order_P12_IPI_Min\"'),
                                                          F.col('\"Order_P6_IPI_Stddev\"'),F.col('\"Order_P12_IPI_Stddev\"'),
                                                          F.col('\"Months_from_P12_Latest_Order\"'),F.col('\"P12_Latest_NonZero_Order_Quantity\"'),F.col('\"Months_from_P12_Latest_Zero\"'),
                                                          F.col('\"Months_from_P12_Latest_Order_L1\"'),F.col('\"P12_Latest_NonZero_Order_Quantity_L1\"'),F.col('\"Months_from_P12_Latest_Zero_L1\"'),
                                                          F.col('\"Months_from_P12_Latest_Order_L2\"'),F.col('\"P12_Latest_NonZero_Order_Quantity_L2\"'),F.col('\"Months_from_P12_Latest_Zero_L2\"'),
                                                          F.col('\"Months_from_P12_Latest_Order_L3\"'),F.col('\"P12_Latest_NonZero_Order_Quantity_L3\"'),F.col('\"Months_from_P12_Latest_Zero_L3\"'),
                                                          F.col('\"Months_from_P12_Latest_Order_L4\"'),F.col('\"P12_Latest_NonZero_Order_Quantity_L4\"'),F.col('\"Months_from_P12_Latest_Zero_L4\"'),
                                                          F.col('\"Order_P6_IPI_Avg_L1\"'),F.col('\"Order_P6_IPI_Avg_L2\"'),F.col('\"Order_P6_IPI_Avg_L3\"'),F.col('\"Order_P6_IPI_Avg_L4\"'),
                                                          F.col('\"Order_P6_IPI_Max_L1\"'),F.col('\"Order_P6_IPI_Max_L2\"'),F.col('\"Order_P6_IPI_Max_L3\"'),F.col('\"Order_P6_IPI_Max_L4\"'),
                                                          F.col('\"Order_P6_IPI_Min_L1\"'),F.col('\"Order_P6_IPI_Min_L2\"'),F.col('\"Order_P6_IPI_Min_L3\"'),F.col('\"Order_P6_IPI_Min_L4\"'),
                                                          F.col('\"Order_P6_IPI_Stddev_L1\"'),F.col('\"Order_P6_IPI_Stddev_L2\"'),F.col('\"Order_P6_IPI_Stddev_L3\"'),F.col('\"Order_P6_IPI_Stddev_L4\"'),
                                                          F.col('\"Order_P6_IPI_Velocity\"'),F.col('\"Order_P6_IPI_Index\"'),
                                                          F.col('\"Order_P6_IPI_Velocity_L1\"'),F.col('\"Order_P6_IPI_Velocity_L2\"'),F.col('\"Order_P6_IPI_Velocity_L3\"'),F.col('\"Order_P6_IPI_Velocity_L4\"'),
                                                          F.col('\"Order_P6_IPI_Index_L1\"'),F.col('\"Order_P6_IPI_Index_L2\"'),F.col('\"Order_P6_IPI_Index_L3\"'),F.col('\"Order_P6_IPI_Index_L4\"')
                                                          )

    sp_df_order_qty_ts_feat = sp_df_store_summ_feat.join(sp_df_order_qty_lag_summ_velocity_feat,[f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'],how='left'
                                                        #,rsuffix="_right"
                                                        )

    sp_df_order_qty_ts_feat = sp_df_order_qty_ts_feat.join(sp_df_order_qty_ipi_feat,[f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'],how='left'
                                                           #,rsuffix="_right"
                                                           )


    derive_col="Monthly_Store_Product_Sales_Quantity_Log"
    logger.info(f'create time series lag and window velocity change features for the variable - \"{derive_col}\"')
    sp_df_sales_qty_lag_summ = ts_lag_summ (session=session,
                                            base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                            derive_col=derive_col,
                                            look_back_window_length=3,n_window=4,
                                            velocity=True,nonzero=False)

    sp_df_sales_qty_lag_summ_feat = sp_df_sales_qty_lag_summ.drop(f'\"{derive_col}\"'
                                                                 ,f'\"{derive_col}_P1_Velocity\"'
                                                                 ,f'\"{derive_col}_P1_Index\"'
                                                                 #,f'\"{derive_col}_P12_Sum\"'
                                                                 )

    sp_df_sales_qty_ts_feat = ts_window_velocity (session=session,
                                                  ts_summ_snowpark_df=sp_df_sales_qty_lag_summ_feat,
                                                  customer_col=customer_col,product_col=product_col,date_col=date_col,derive_col=derive_col,
                                                  look_back_window_length=3,n_window=2,n_window_lag=4)

    derive_col="Monthly_Store_Product_Number_Of_Orders"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_num_order_lag_summ = ts_lag_summ (session=session,
                                            base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                            derive_col=derive_col,
                                            look_back_window_length=3,n_window=4,
                                            velocity=True,nonzero=False)

    drop_cols = tuple([col for col in sp_df_num_order_lag_summ.columns if '_Count_Zero' in col])
    drop_cols = (f'\"{derive_col}\"' ,f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
            ) + drop_cols
    sp_df_num_order_ts_feat = sp_df_num_order_lag_summ.drop(drop_cols)

    
    derive_col="Monthly_Store_Product_Avg_Quantity_per_Order_Log"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_avg_order_qty_lag_summ = ts_lag_summ (session=session,
                                                base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                                derive_col=derive_col,
                                                look_back_window_length=3,n_window=4,
                                                velocity=True,nonzero=False)

    drop_cols = tuple([col for col in sp_df_avg_order_qty_lag_summ.columns if '_Count_Zero' in col])
    drop_cols = drop_cols + tuple([col for col in sp_df_avg_order_qty_lag_summ.columns if '_Sum' in col])
    drop_cols = (f'\"{derive_col}\"' ,f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
            ) + drop_cols

    sp_df_avg_order_qty_ts_feat = sp_df_avg_order_qty_lag_summ.drop(drop_cols)

    
    derive_col="Monthly_Store_Level5_Order_Quantity_Log"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_level_order_qty_lag_summ = ts_lag_summ (session=session,
                                                  base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                                  derive_col=derive_col,
                                                  look_back_window_length=3,n_window=4,
                                                  velocity=True,nonzero=False)

    drop_cols = (f'\"{derive_col}\"' ,f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
                ) 

    sp_df_level_order_qty_ts_feat = sp_df_level_order_qty_lag_summ.drop(drop_cols)


    derive_col="Monthly_Store_Manufacturer_Brand_Order_Quantity_Log"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_brand_order_qty_lag_summ = ts_lag_summ (session=session,
                                                  base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                                  derive_col=derive_col,
                                                  look_back_window_length=3,n_window=4,
                                                  velocity=True,nonzero=False)
    
    drop_cols = (f'\"{derive_col}\"' ,f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
                ) 
    sp_df_brand_order_qty_ts_feat = sp_df_brand_order_qty_lag_summ.drop(drop_cols)

    
    derive_col="Monthly_Store_Active_Ingredient_Order_Quantity_Log"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_act_ing_order_qty_lag_summ = ts_lag_summ (session=session,
                                                    base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                                    derive_col=derive_col,
                                                    look_back_window_length=3,n_window=4,
                                                    velocity=True,nonzero=False)
    
    drop_cols = (f'\"{derive_col}\"' ,f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
                ) 
    sp_df_act_ing_order_qty_ts_feat = sp_df_act_ing_order_qty_lag_summ.drop(drop_cols)

    
    derive_col="Monthly_Store_Level5_Sales_Quantity_Log"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_level_sales_qty_lag_summ = ts_lag_summ (session=session,
                                                  base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                                  derive_col=derive_col,
                                                  look_back_window_length=3,n_window=4,
                                                  velocity=True,nonzero=False)
    drop_cols = (f'\"{derive_col}\"' ,f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
                ) 
    sp_df_level_sales_qty_ts_feat = sp_df_level_sales_qty_lag_summ.drop(drop_cols)


    derive_col="Monthly_Store_Manufacturer_Brand_Sales_Quantity_Log"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_brand_sales_qty_lag_summ = ts_lag_summ (session=session,
                                                  base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                                  derive_col=derive_col,
                                                  look_back_window_length=3,n_window=4,
                                                  velocity=True,nonzero=False)

    drop_cols = (f'\"{derive_col}\"' ,f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
                ) 
    sp_df_brand_sales_qty_ts_feat = sp_df_brand_sales_qty_lag_summ.drop(drop_cols)


    derive_col="Monthly_Store_Active_Ingredient_Sales_Quantity_Log"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_act_ing_sales_qty_lag_summ = ts_lag_summ (session=session,
                                                    base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                                    derive_col=derive_col,
                                                    look_back_window_length=3,n_window=4,
                                                    velocity=True,nonzero=False)

    drop_cols = (f'\"{derive_col}\"' ,f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
                ) 
    sp_df_act_ing_sales_qty_ts_feat = sp_df_act_ing_sales_qty_lag_summ.drop(drop_cols)


    derive_col="Monthly_Sigma_Availability_Opportunity_Quantity_Log"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_avail_opp_qty_lag_summ = ts_lag_summ (session=session,
                                                base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                                derive_col=derive_col,
                                                look_back_window_length=3,n_window=1,
                                                velocity=False,nonzero=False)

    drop_cols = tuple([col for col in sp_df_avail_opp_qty_lag_summ.columns if '_Stddev' in col])
    drop_cols = tuple([col for col in sp_df_avail_opp_qty_lag_summ.columns if '_Max' in col])+drop_cols
    drop_cols = tuple([col for col in sp_df_avail_opp_qty_lag_summ.columns if '_Min' in col])+drop_cols
    drop_cols = (f'\"{derive_col}\"',#f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
                ) + drop_cols
    sp_df_avail_opp_qty_ts_feat = sp_df_avail_opp_qty_lag_summ.drop(drop_cols)

    derive_col="MCS_Days_In_Month"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_mcs_days_lag_summ = ts_lag_summ (session=session,
                                           base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                           derive_col=derive_col,
                                           look_back_window_length=3,n_window=1,
                                           velocity=False,nonzero=False)

    sp_df_days_in_month = session.table(base_feat_table_name).select(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"'),F.col(f'\"{date_col}\"'),F.col('\"Days_In_Month\"'))

    windowSpec = Window.partition_by(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"')).order_by(F.col(f'\"{date_col}\"').asc())
    windowRows = windowSpec.rowsBetween(-3, -1)

    sp_df_days_in_month = sp_df_days_in_month.withColumn('\"Days_In_Month_P3_Sum\"',F.sum(F.col('\"Days_In_Month\"')).over(windowRows)) 
    sp_df_mcs_days_lag_summ = sp_df_mcs_days_lag_summ.join(sp_df_days_in_month,[f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'],how='left')
    sp_df_mcs_days_lag_summ = sp_df_mcs_days_lag_summ.withColumn(f'\"{derive_col}_P3_Fraction\"',F.round(100*F.col(f'\"{derive_col}_P3_Sum\"')/F.col('\"Days_In_Month_P3_Sum\"'),1))

    drop_cols = tuple([col for col in sp_df_mcs_days_lag_summ.columns if '_Stddev' in col])
    drop_cols = tuple([col for col in sp_df_mcs_days_lag_summ.columns if '_Max' in col])+drop_cols
    drop_cols = tuple([col for col in sp_df_mcs_days_lag_summ.columns if '_Min' in col])+drop_cols
    drop_cols = (f'\"{derive_col}\"' #,f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
                 ,'\"Days_In_Month\"','\"Days_In_Month_P3_Sum\"',
                 ) + drop_cols

    sp_df_mcs_days_ts_feat = sp_df_mcs_days_lag_summ.drop(drop_cols)

    derive_col="OOS_Days_In_Month"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_oos_days_lag_summ = ts_lag_summ (session=session,
                                           base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                           derive_col=derive_col,
                                           look_back_window_length=3,n_window=1,
                                           velocity=False,nonzero=False)

    sp_df_oos_days_lag_summ = sp_df_oos_days_lag_summ.join(sp_df_days_in_month,[f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'],how='left')
    sp_df_oos_days_lag_summ = sp_df_oos_days_lag_summ.withColumn(f'\"{derive_col}_P3_Fraction\"',F.round(100*F.col(f'\"{derive_col}_P3_Sum\"')/F.col('\"Days_In_Month_P3_Sum\"'),1))

    drop_cols = tuple([col for col in sp_df_oos_days_lag_summ.columns if '_Stddev' in col])
    drop_cols = tuple([col for col in sp_df_oos_days_lag_summ.columns if '_Max' in col])+drop_cols
    drop_cols = tuple([col for col in sp_df_oos_days_lag_summ.columns if '_Min' in col])+drop_cols
    drop_cols = (f'\"{derive_col}\"' #,f'\"{derive_col}_P1_Velocity\"',f'\"{derive_col}_P1_Index\"'#,f'\"{derive_col}_P12_Sum\"'
                 ,'\"Days_In_Month\"','\"Days_In_Month_P3_Sum\"',
                ) + drop_cols

    sp_df_oos_days_ts_feat = sp_df_oos_days_lag_summ.drop(drop_cols)

    derive_col="Monthly_Compliance"
    logger.info(f'create time series lag features for the variable - \"{derive_col}\"')
    sp_df_compliance_lag_summ = ts_lag_summ (session=session,
                                             base_feat_table_name=base_feat_table_name,customer_col=customer_col,product_col=product_col,date_col=date_col,
                                             derive_col=derive_col,
                                             look_back_window_length=3,n_window=1,
                                             velocity=False,nonzero=False)

    sp_df_compliance_ts_feat = sp_df_compliance_lag_summ.select(F.col(f'\"{customer_col}\"'),F.col(f'\"{product_col}\"'),F.col(f'\"{date_col}\"'),
                                                            F.col(f'\"{derive_col}_L1\"'),F.col(f'\"{derive_col}_L2\"'),F.col(f'\"{derive_col}_L3\"')
                                                            )
    logger.info(f'join all time series features')
    sp_df_derive_ts_feat = sp_df_order_qty_ts_feat.join(sp_df_sales_qty_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_num_order_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_avg_order_qty_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_level_order_qty_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_brand_order_qty_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_act_ing_order_qty_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_level_sales_qty_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_brand_sales_qty_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_act_ing_sales_qty_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_avail_opp_qty_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_mcs_days_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_oos_days_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left') \
                                                  .join(sp_df_compliance_ts_feat, [f'\"{customer_col}\"',f'\"{product_col}\"',f'\"{date_col}\"'], how='left')
    
    logger.info(f'write the snowpark dataframe to Snowflake table')
    output_table_name=args.sf_output_table #"BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_TS_FEAT_LOG"
    sp_df_derive_ts_feat.write.mode("overwrite").save_as_table(output_table_name, table_type="")

    logger.info(f'time series feature tabele has been created/updated')
    #print("Time series feature tabele has been updated")


if __name__ == "__main__":
    main()


