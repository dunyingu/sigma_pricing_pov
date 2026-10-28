import os
import argparse
import logging

import snowflake.connector
import snowflake.snowpark
from snowflake.snowpark.session import Session
#from snowflake.snowpark.types import PandasSeries, PandasDataFrame

import Config

import pandas as pd
import numpy as np


import datetime
from datetime import datetime
from datetime import date


import catboost
from catboost import Pool, CatBoostRegressor, CatBoostClassifier, EShapCalcType, EFeaturesSelectionAlgorithm
from catboost.utils import eval_metric

import random 
from scipy import stats

import joblib
import utils


def main():
    """Main function of the script."""

    # input and output arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--sf_database", type=str, help="snowflake database")
    parser.add_argument("--sf_schema", type=str, help="snowflake database schema")
    #parser.add_argument("--sf_table", type=str, help="snowflake table")

    #parser.add_argument("--score_start_date", type=str, help="score data start date")
    #parser.add_argument("--score_end_date", type=str, help="score data cutoff date")
    
    #parser.add_argument("--regression_selected_feat_file_name", type=str, help="selected feat list for regression model") # follow name convention, example: pricing_poc_catboost_regression_selected_feat; pricing_poc_catboost_classification_selected_feat
    #parser.add_argument("--classifier_selected_feat_file_name", type=str, help="selected feat list for classification model") # follow name convention, example: pricing_poc_catboost_regression_selected_feat; pricing_poc_catboost_classification_selected_feat
    #parser.add_argument("--regression_model_name", type=str, help="regression model name to predict quantity") # follow name convention, example: pricing_poc_catboost_regression_model; pricing_poc_catboost_classification_model
    #parser.add_argument("--classifier_model_name", type=str, help="classification model name to predict propensity of ordering") # follow name convention, example: pricing_poc_catboost_regression_model; pricing_poc_catboost_classification_model
    
    parser.add_argument("--score_output_table_name", type=str, help="snowflake score output table name")

    # set up logger
    logger = logging.getLogger('prcing_model_score_rollup_at_product_level')
    format = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
    #logger.addHandler(logging.StreamHandler().setFormatter(format))
    handler=logging.StreamHandler()
    handler.setFormatter(format)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

    # load args
    logger.info("load args")
    args = parser.parse_args()
    print(" ".join(f"{k}={v}" for k, v in vars(args).items()))

    # set up sf session
    logger.info("set up snowflake session")
    session = Config.get_sf_session(KeyVault=Config.KeyVault)
    session.use_database(args.sf_database)
    session.use_schema(args.sf_schema)


    # load selected feat list
    logger.info("load selected feat list")

    sql_files = """
    --list @MODELS/pricing
    select distinct METADATA$FILENAME "filename", METADATA$FILE_LAST_MODIFIED "last_modified"
    from @MODELS/pricing
    """
    df_files = session.sql(sql_files).to_pandas()
    
    list_name_check = f'_regression_selected_feat_list'
    at_list = df_files[df_files.filename.str.contains(list_name_check)]
    at_list = at_list[at_list['last_modified']==max(at_list.last_modified)]
    file_name = list(at_list['filename'])[0].split('/')[-1]

    regress_select_feat_list = utils.get_file_sf(session=session, 
    											 file_path='pricing',
    											 file_name=file_name,
    											 tmppath='./tmp')


    # load score data
    logger.info("load data from score feature table")

    col_names = (',').join([f'\"{feat}\"' for feat in regress_select_feat_list])
    target = "Monthly_Store_Product_Order_Quantity"
    log_target = "Monthly_Store_Product_Order_Quantity_Log"
    label= "Monthly_Store_Product_Order_Label"
    cat_feat = ["Store_Code","Product_Code","MonthofYear","Store_State_Code","Retail_Pricing_Zone","LEVEL5_GROUP","Manufacturer_Brand","Active_Ingredient","Is_Private_Label_Flag"]

    sql_qry = f"""
    select 
    "Month_Start_Date"
    ,{col_names}
    ,"Monthly_Avg_Cost_Price_I"
    ,"Monthly_Avg_Nett_Price_I"
    ,"P12M_Max_Avg_Margin_I"
    ,"P12M_Min_Avg_Margin_I"
    ,"Monthly_Avg_Nett_Price_Perm"
    ,"Price_Change_Level"
    ,\"{target}\"
    ,\"{log_target}\"
    ,\"{label}\"
    from 
    (select
    a.*,
    b."Monthly_Avg_Nett_Price_Perm",
    round(b."Monthly_Avg_Nett_Price_Perm"/a."Monthly_Avg_Nett_Price_I",2) as "Price_Change_Level",
    round(100*(b."Monthly_Avg_Nett_Price_Perm"-a."Monthly_Avg_Cost_Price_I")/a."Monthly_Avg_Cost_Price_I",2) as "Monthly_Avg_Margin_I",
    "Monthly_Avg_Margin_I"-a."P12M_Max_Avg_Margin_I" as "Monthly_Diff_Max_Avg_Margin_Perm",
    case when "Monthly_Avg_Margin_I"=0 and a."P12M_Max_Avg_Margin_I"=0 then 0
      	 when "Monthly_Avg_Margin_I">0 and a."P12M_Max_Avg_Margin_I"<=0 then 10000
      	 when "Monthly_Avg_Margin_I"<0 and a."P12M_Max_Avg_Margin_I"=0 then -10000
      	 when "Monthly_Avg_Margin_I"<=0 and a."P12M_Max_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Max_Avg_Margin_Perm"/a."P12M_Max_Avg_Margin_I",1)
      	 else round(100*"Monthly_Diff_Max_Avg_Margin_Perm"/a."P12M_Max_Avg_Margin_I",1) end as "Monthly_Index_Max_Avg_Margin_I",
    "Monthly_Avg_Margin_I"-a."P12M_Min_Avg_Margin_I" as "Monthly_Diff_Min_Avg_Margin_Perm",
    case when "Monthly_Avg_Margin_I"=0 and a."P12M_Min_Avg_Margin_I"=0 then 0
      	 when "Monthly_Avg_Margin_I">0 and a."P12M_Min_Avg_Margin_I"<=0 then 10000
      	 when "Monthly_Avg_Margin_I"<0 and a."P12M_Min_Avg_Margin_I"=0 then -10000
      	 when "Monthly_Avg_Margin_I"<=0 and a."P12M_Min_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Min_Avg_Margin_Perm"/a."P12M_Min_Avg_Margin_I",1)
      	 else round(100*"Monthly_Diff_Min_Avg_Margin_Perm"/a."P12M_Min_Avg_Margin_I",1) end as "Monthly_Index_Min_Avg_Margin_I",
    c.*exclude("Month_Start_Date","Store_Code","Product_Code")
    from 
    (select distinct 
    "Month_Start_Date",
    "Store_Code",
    "Product_Code",
    "Monthly_Avg_Cost_Price_I",
    "Monthly_Avg_Nett_Price_I",
    "P12M_Max_Avg_Margin_I",
    "P12M_Min_Avg_Margin_I"
    from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG_PERM
    ) a
    left join (select distinct
    "Month_Start_Date",
    "Product_Code",
    "Monthly_Avg_Nett_Price_Perm"
    from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG_PERM) b
    on a."Month_Start_Date"=b."Month_Start_Date"
    and a."Product_Code"=b."Product_Code"
    join
    (
    select distinct 
    * exclude(
    "Monthly_Avg_Margin_I",
    "Monthly_Index_Max_Avg_Margin_I",
    "Monthly_Index_Min_Avg_Margin_I"
    ,"Insertion_Date"
    )
    from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG
    ) c
    on a."Month_Start_Date"=c."Month_Start_Date"
    and a."Store_Code"=c."Store_Code"
    and a."Product_Code"=c."Product_Code"
    )
    ;
    """

    df_score = session.sql(sql_qry).to_pandas()
    df_score["Month_Start_Date"]=pd.to_datetime(df_score["Month_Start_Date"])

    for feat in cat_feat:
    	if feat in list(df_score.columns):
    		df_score[feat]=df_score[feat].fillna('')
    	else:
    		continue

    X_score_regress = df_score[regress_select_feat_list]

    # load models
    logger.info("load models")

    model_name_check = f'_regression_model'
    at_model = df_files[df_files.filename.str.contains(model_name_check)]
    at_model = at_model[at_model['last_modified']==max(at_model.last_modified)]
    model_name = list(at_model['filename'])[0].split('/')[-1]

    regress_model = utils.get_file_sf(session=session, 
    								  file_path='pricing',
    								  file_name=model_name,
    								  tmppath='./tmp')


    logger.info("make predictions and scoring")
    y_log_pred = regress_model.predict(X_score_regress)
    y_pred = np.ceil(np.exp(y_log_pred)-1)

    df_price_perm_score = df_score[["Store_Code","Product_Code","Month_Start_Date","Monthly_Avg_Cost_Price_I","Monthly_Avg_Nett_Price_I",
                                    "Price_Change_Level","Monthly_Avg_Nett_Price_Perm",
                                    "Monthly_Avg_Margin_I","Monthly_Index_Max_Avg_Margin_I","Monthly_Index_Min_Avg_Margin_I",log_target,target]]

    df_price_perm_score["Monthly_Store_Product_Order_Quantity_Log_Pred"]=y_log_pred
    df_price_perm_score["Monthly_Store_Product_Order_Quantity_Pred"]=y_pred

    df_price_perm_score["Monthly_Store_Product_Order_Revenue_Pred"]=df_price_perm_score["Monthly_Avg_Nett_Price_Perm"]*df_price_perm_score["Monthly_Store_Product_Order_Quantity_Pred"]
    df_price_perm_score["Monthly_Store_Product_Order_Cost_Pred"]=df_price_perm_score["Monthly_Avg_Cost_Price_I"]*df_price_perm_score["Monthly_Store_Product_Order_Quantity_Pred"]
    df_price_perm_score["Monthly_Store_Product_Order_GP_Pred"]=df_price_perm_score["Monthly_Store_Product_Order_Revenue_Pred"]-df_price_perm_score["Monthly_Store_Product_Order_Cost_Pred"]

    df_prod_price = df_price_perm_score.groupby(["Month_Start_Date","Product_Code","Monthly_Avg_Nett_Price_Perm"]).agg({"Monthly_Avg_Cost_Price_I":['min','max'], "Monthly_Avg_Nett_Price_I": ['min', 'max']})
    df_prod_price.columns = df_prod_price.columns.map('_'.join)
    #col_name = {"Monthly_Avg_Cost_Price_I_min":"Monthly_Avg_Cost_Price_I_min","Monthly_Avg_Cost_Price_I_max":"Monthly_Avg_Cost_Price_I_max","Monthly_Avg_Nett_Price_I_min":"Monthly_Avg_Nett_Price_I_Min","Monthly_Avg_Nett_Price_I_max":"Monthly_Avg_Nett_Price_I_Max"}
    df_prod_price = df_prod_price.reset_index()#.rename(columns=col_name)

    df_prod_price_perm_rev_gp = df_price_perm_score.groupby(["Month_Start_Date","Product_Code","Monthly_Avg_Nett_Price_Perm"])[target,"Monthly_Store_Product_Order_Quantity_Pred","Monthly_Store_Product_Order_Revenue_Pred","Monthly_Store_Product_Order_GP_Pred"].sum().reset_index().rename(columns={"Monthly_Store_Product_Order_Quantity":"Monthly_Product_Order_Quantity","Monthly_Store_Product_Order_Quantity_Pred":"Monthly_Product_Order_Quantity_Pred","Monthly_Store_Product_Order_Revenue_Pred":"Monthly_Product_Order_Revenue_Pred","Monthly_Store_Product_Order_GP_Pred":"Monthly_Product_Order_GP_Pred"})
    df_prod_price_perm_score = pd.merge(df_prod_price, df_prod_price_perm_rev_gp, how='left', left_on=["Month_Start_Date","Product_Code","Monthly_Avg_Nett_Price_Perm"], right_on = ["Month_Start_Date","Product_Code","Monthly_Avg_Nett_Price_Perm"])


    df_prod_price_perm_score["Recomm_Nett_Price_Revenue"]=0
    df_prod_price_perm_score["Recomm_Nett_Price_GP"]=0

    idx_revenue = df_prod_price_perm_score.groupby(["Product_Code","Month_Start_Date"])["Monthly_Product_Order_Revenue_Pred"].transform(max) == df_prod_price_perm_score["Monthly_Product_Order_Revenue_Pred"]
    df_prod_price_perm_score.loc[idx_revenue,"Recomm_Nett_Price_Revenue"]=1

    idx_gp = df_prod_price_perm_score.groupby(["Product_Code","Month_Start_Date"])["Monthly_Product_Order_GP_Pred"].transform(max) == df_prod_price_perm_score["Monthly_Product_Order_GP_Pred"]
    df_prod_price_perm_score.loc[idx_gp,"Recomm_Nett_Price_GP"]=1

    df_prod_price_perm_score["Month_Start_Date"]=df_prod_price_perm_score["Month_Start_Date"].astype(str)
    df_prod_price_perm_score["Insertion_Date"]=date.today().strftime("%Y-%m-%d")

    sp_df_prod_price_perm_score = session.write_pandas(df_prod_price_perm_score, args.score_output_table_name, auto_create_table=True, overwrite=True, table_type="")

    return 'scoring job successfully completed'



if __name__ == "__main__":
    main()