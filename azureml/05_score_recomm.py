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

import sklearn
from sklearn.preprocessing import OrdinalEncoder#, LabelEncoder, OneHotEncoder, MinMaxScaler, PowerTransformer
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import MinMaxScaler
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.metrics import mean_squared_error, mean_squared_log_error, mean_absolute_error

import catboost
from catboost import Pool, CatBoostRegressor, CatBoostClassifier, EShapCalcType, EFeaturesSelectionAlgorithm
from catboost.utils import eval_metric

import random 
from scipy import stats


import mlflow
from mlflow.deployments import get_deploy_client

import joblib
import utils


def main():
    """Main function of the script."""

    # input and output arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--sf_database", type=str, help="snowflake database")
    parser.add_argument("--sf_schema", type=str, help="snowflake database schema")
    parser.add_argument("--sf_table", type=str, help="snowflake table")

    #parser.add_argument("--score_start_date", type=str, help="score data start date")
    #parser.add_argument("--score_end_date", type=str, help="score data cutoff date")
    
    #parser.add_argument("--regression_selected_feat_file_name", type=str, help="selected feat list for regression model") # follow name convention, example: pricing_poc_catboost_regression_selected_feat; pricing_poc_catboost_classification_selected_feat
    #parser.add_argument("--classifier_selected_feat_file_name", type=str, help="selected feat list for classification model") # follow name convention, example: pricing_poc_catboost_regression_selected_feat; pricing_poc_catboost_classification_selected_feat
    #parser.add_argument("--regression_model_name", type=str, help="regression model name to predict quantity") # follow name convention, example: pricing_poc_catboost_regression_model; pricing_poc_catboost_classification_model
    #parser.add_argument("--classifier_model_name", type=str, help="classification model name to predict propensity of ordering") # follow name convention, example: pricing_poc_catboost_regression_model; pricing_poc_catboost_classification_model
    
    parser.add_argument("--score_output_table_name", type=str, help="snowflake score output table name")


    # set up logger
    logger = logging.getLogger('prcing_model_score')
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

    # load score data
    logger.info("load data from score feature table")
    feat_table_name = args.sf_table
    df_raw_feat = session.table(feat_table_name).to_pandas()

    df_feat = df_raw_feat.copy()
    
    df_feat["Month_Start_Date"]=pd.to_datetime(df_feat["Month_Start_Date"])
    #df_feat["MonthofYear"]=df_feat["MonthofYear"].astype(str)
    df_feat["Store_State_Code"]=df_feat["Store_State_Code"].fillna('')
    df_feat["Retail_Pricing_Zone"]=df_feat["Retail_Pricing_Zone"].fillna('')
    df_feat["LEVEL5_GROUP"]=df_feat["LEVEL5_GROUP"].fillna('')
    df_feat["Manufacturer_Brand"]=df_feat["Manufacturer_Brand"].fillna('')
    df_feat["Active_Ingredient"]=df_feat["Active_Ingredient"].fillna('')
    #df_feat["Is_Private_Label_Flag"]=df_feat["Is_Private_Label_Flag"].astype(str)
    df_feat["Is_Private_Label_Flag"]=df_feat["Is_Private_Label_Flag"].fillna('')

    target = "Monthly_Store_Product_Order_Quantity"
    log_target = "Monthly_Store_Product_Order_Quantity_Log"
    label= "Monthly_Store_Product_Order_Label"
    cat_feat = ["Store_Code","Product_Code","MonthofYear","Store_State_Code","Retail_Pricing_Zone","LEVEL5_GROUP","Manufacturer_Brand","Active_Ingredient","Is_Private_Label_Flag"]

    # create score dataset
    logger.info("create score dataset")
    #df_score = df_feat[(df_feat["Month_Start_Date"]>=args.score_start_date)&(df_feat["Month_Start_Date"]<=args.score_end_date)]
    df_score=df_feat
    #drop_col_list=["Month_Start_Date"]
    #df_score.drop(drop_col_list,axis=1,inplace=True)
    drop_col="Month_Start_Date"
    X_score = df_score.drop(columns=[drop_col,target,log_target,label],axis=1)

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

    list_name_check = f'_classification_selected_feat_list'
    at_list = df_files[df_files.filename.str.contains(list_name_check)]
    at_list = at_list[at_list['last_modified']==max(at_list.last_modified)]
    file_name = list(at_list['filename'])[0].split('/')[-1]

    classifier_select_feat_list = utils.get_file_sf(session=session, 
    												file_path='pricing',
    												file_name=file_name,
    												tmppath='./tmp')

    #conn_string = Config.get_azure_storage_cred() #Config.get_azure_storage_cred(storage_account=Config.storage_account)['connection_string']
    #container = Config.storage_container #Config.get_azure_storage_cred(storage_account=Config.storage_account)['container']

    #regress_select_feat_list = get_file_azure(connection_str=conn_string,
    #										  container_name=container,
    #										  blob_folder='pricing', 
    #										  file_name=file_name)



    #classifier_select_feat_list = get_file_azure(connection_str=conn_string,
    #										  	  container_name=container,
    #										      blob_folder='pricing', 
    #										      file_name=file_name)

    X_score_regress = X_score[regress_select_feat_list]
    X_score_classifer = X_score[classifier_select_feat_list]


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

    model_name_check = f'_classification_model'
    at_model = df_files[df_files.filename.str.contains(model_name_check)]
    at_model = at_model[at_model['last_modified']==max(at_model.last_modified)]
    model_name = list(at_model['filename'])[0].split('/')[-1]

    classifier_model = utils.get_file_sf(session=session, 
   										file_path='pricing',
   										file_name=model_name,
   										tmppath='./tmp')


   #regress_model = get_file_azure(connection_str=conn_string,
    #							   container_name=container,
    #							   blob_folder='pricing', 
    #							   file_name=model_name)



    #classifier_model = get_file_azure(connection_str=conn_string,
    #								   container_name=container,
    #								   blob_folder='pricing', 
    #								   file_name=model_name)
    
    # predict and score
    logger.info("make predictions and scoring")
    y_log_pred = regress_model.predict(X_score_regress)
    y_pred = np.exp(y_log_pred)-1

    y_label = classifier_model.predict(X_score_classifer)
    y_label_prob = classifier_model.predict_proba(X_score_classifer)

    y_pred_label = np.clip(np.multiply(y_pred,y_label),a_min=0,a_max=None)
    y_score = np.ceil(y_pred_label)

    # return dataframe with scoring output and recommended price to achieve best revenue or gp
    logger.info("set recommended nett price for best revenue or gp")
    df_price_perm_score = df_score[["Store_Code","Product_Code","Month_Start_Date","Monthly_Avg_Cost_Price_I","Monthly_Avg_Nett_Price_I",
                                    "Price_Change_Level","Monthly_Avg_Nett_Price_Perm",
                                    "Monthly_Avg_Margin_I","Monthly_Index_Max_Avg_Margin_I","Monthly_Index_Min_Avg_Margin_I",log_target,target]]

    df_price_perm_score["Monthly_Store_Product_Order_Quantity_Log_Pred"]=y_log_pred
    df_price_perm_score["Monthly_Store_Product_Order_Quantity_Pred"]=np.ceil(np.clip(y_pred,a_min=0,a_max=None))
    df_price_perm_score["Monthly_Store_Product_Order_Propensity"]=y_label_prob[:,1]
    df_price_perm_score["Monthly_Store_Product_Order_Label_Pred"]=y_label
    df_price_perm_score["Monthly_Store_Product_Order_Quantity_Forecast"]=y_score

    df_price_perm_score["Monthly_Store_Product_Order_Revenue_Pred"]=df_price_perm_score["Monthly_Avg_Nett_Price_Perm"]*df_price_perm_score["Monthly_Store_Product_Order_Quantity_Pred"]
    df_price_perm_score["Monthly_Store_Product_Order_Cost_Pred"]=df_price_perm_score["Monthly_Avg_Cost_Price_I"]*df_price_perm_score["Monthly_Store_Product_Order_Quantity_Pred"]
    df_price_perm_score["Monthly_Store_Product_Order_GP_Pred"]=df_price_perm_score["Monthly_Store_Product_Order_Revenue_Pred"]-df_price_perm_score["Monthly_Store_Product_Order_Cost_Pred"]

    df_price_perm_score["Recomm_Nett_Price_Revenue"]=0
    df_price_perm_score["Recomm_Nett_Price_GP"]=0

    #idx_revenue = df_price_perm_score.groupby(["Store_Code","Product_Code","Month_Start_Date"])["Monthly_Store_Product_Order_Revenue_Pred"].idxmax()
    idx_revenue = df_price_perm_score.groupby(["Store_Code","Product_Code","Month_Start_Date"])["Monthly_Store_Product_Order_Revenue_Pred"].transform(max) == df_price_perm_score["Monthly_Store_Product_Order_Revenue_Pred"]
    df_price_perm_score.loc[idx_revenue,"Recomm_Nett_Price_Revenue"]=1

    #idx_gp = df_price_perm_score.groupby(["Store_Code","Product_Code","Month_Start_Date"])["Monthly_Store_Product_Order_GP_Pred"].idxmax()
    idx_gp = df_price_perm_score.groupby(["Store_Code","Product_Code","Month_Start_Date"])["Monthly_Store_Product_Order_GP_Pred"].transform(max) == df_price_perm_score["Monthly_Store_Product_Order_GP_Pred"]
    df_price_perm_score.loc[idx_gp,"Recomm_Nett_Price_GP"]=1

    # write the result back to snowflake
    logger.info("write dataframe to snowflake")
    df_price_perm_score["Month_Start_Date"]=df_price_perm_score["Month_Start_Date"].astype(str)

    sp_df_price_perm_score = session.write_pandas(df_price_perm_score, args.score_output_table_name, auto_create_table=True, overwrite=True, table_type="") #overwrite=True

    
    return 'scoring job successfully completed'



if __name__ == "__main__":
    main()