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

    parser.add_argument("--nonzero", type=str, default='no', help="only use non-zero orders")
    parser.add_argument("--train_ratio", type=float, default=0.8, help="percentage of dataset used to train models")
    #parser.add_argument("--train_start_date", type=str, help="train data start date")
    #parser.add_argument("--train_end_date", type=str, help="train data cutoff date")
    #parser.add_argument("--val_start_date", type=str, help="val data start date")
    #parser.add_argument("--val_end_date", type=str, help="val data cutoff date")

    parser.add_argument("--model_type", type=str, help="classification or regression")

    parser.add_argument("--selected_feat_file_name", type=str, help="output file name") # follow name convention, example: pricing_poc_catboost_regression_selected_feat; pricing_poc_catboost_classification_selected_feat

    # set up logger
    logger = logging.getLogger('prcing_feature_selection')
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

    # load train data
    logger.info("load data from feature table")
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

    df_feat = df_feat[~df_feat["Monthly_Avg_Margin_I"].isnull()]

    target = "Monthly_Store_Product_Order_Quantity"
    log_target = "Monthly_Store_Product_Order_Quantity_Log"
    label= "Monthly_Store_Product_Order_Label"
    cat_feat = ["Store_Code","Product_Code","MonthofYear","Store_State_Code","Retail_Pricing_Zone","LEVEL5_GROUP","Manufacturer_Brand","Active_Ingredient","Is_Private_Label_Flag"]

    if args.nonzero=='yes':
        df_feat = df_feat[df_feat[target]>0]

    # create train and val dataset
    logger.info("create train and val dataset")
    month_list = sorted(list(df_feat["Month_Start_Date"].unique()))[:-1]
    train_start_date = str(month_list[:int(len(month_list)*args.train_ratio)][0])[:10]
    print(f'train start date is {train_start_date}')
    train_end_date = str(month_list[:int(len(month_list)*args.train_ratio)][-1])[:10]
    print(f'train end date is {train_end_date}')
    val_start_date = str(month_list[int(len(month_list)*args.train_ratio):][0])[:10]
    print(f'val start date is {val_start_date}')
    val_end_date = str(month_list[int(len(month_list)*args.train_ratio):][-1])[:10]
    print(f'val end date is {val_end_date}')

    df_train = df_feat[(df_feat["Month_Start_Date"]>=train_start_date)&(df_feat["Month_Start_Date"]<=train_end_date)]
    df_val = df_feat[(df_feat["Month_Start_Date"]>=val_start_date)&(df_feat["Month_Start_Date"]<=val_end_date)]
    #drop_col_list=["Store_Code","Product_Code","Month_Start_Date"]
    drop_col_list=["Month_Start_Date"]
    df_train.drop(drop_col_list,axis=1,inplace=True)
    df_val.drop(drop_col_list,axis=1,inplace=True)
    
    X_train = df_train.drop(columns=[target,log_target,label],axis=1)
    X_val = df_val.drop(columns=[target,log_target,label],axis=1)
    
    if args.model_type == 'regression':
        y_train = df_train[log_target] #target
        y_val = df_val[log_target] #target
        
        y_train_actual = df_train[target]
        y_val_actual = df_val[target]
    else:
        y_train = df_train[label]
        y_val = df_val[label]

    train_pool = Pool(X_train, y_train, feature_names=list(X_train.columns), cat_features=cat_feat)
    val_pool = Pool(X_val, y_val, feature_names=list(X_val.columns), cat_features=cat_feat)

    logger.info("train models to select features")
    if args.model_type == 'regression':
        loss_function = 'RMSE'
        evl_metric = 'MAE'
    else:
        loss_function = 'CrossEntropy'
        evl_metric = 'AUC' #'Accuracy','BalancedAccuracy''

    params = { 
            "iterations": 1000
           ,"depth": 6
           ,"l2_leaf_reg": 5
           ,"learning_rate": 0.1
           ,"colsample_bylevel": 0.6
           ,"random_strength": 3
           ,"max_ctr_complexity": 2
           ,'boosting_type': 'Plain'
           #,"monotone_constraints": selected_mono_list
           ,"loss_function": loss_function
           ,"eval_metric": evl_metric
           ,"random_seed": 0
           ,"allow_writing_files": False
           #,"train_dir": '/tmp' #None
    } 
    
    if args.model_type == 'regression':
        selection_model = CatBoostRegressor(**params)
    else:
        selection_model = CatBoostClassifier(**params)

    selection_model.fit(train_pool, plot=False, eval_set=val_pool, verbose=0)

    eval_metrics_dict = utils.train_val_metrics(selection_model, X_train, X_val, y_train_actual, y_val_actual, metric=evl_metric, model_type=args.model_type) 
    metric = eval_metrics_dict[f'Train_{evl_metric}']
    logger.info(f"all features {evl_metric} for Train: {metric}")
    metric = eval_metrics_dict[f'Val_{evl_metric}']
    logger.info(f"all features {evl_metric} for Validation: {metric}")

    logger.info("feature selection process starts")
    df_feat_importance= pd.DataFrame(zip(X_train.columns, selection_model.feature_importances_), columns=['feature', 'importance'])#.set_index('feature')
    df_feat_importance_asc = df_feat_importance.sort_values(by=['importance'], ascending=False)

    feat_num = X_train.shape[1]
    portions = [round(x,1) for x in np.arange(0.2,0.8,0.1)]
    thresholds = [int(np.ceil(p*feat_num)) for p in portions]

    feat_select_summary = dict()
    feat_select_summary[feat_num]=metric

    for i in thresholds:
        imp = df_feat_importance_asc['importance'][i-1] #df_feat_importance_asc.iloc[i-1,:]['importance'][0]
        select_feat_imp = list(df_feat_importance_asc[df_feat_importance_asc['importance']>=imp]['feature'])
        select_feat = [feat for feat in list(X_train.columns) if feat in select_feat_imp]
        
        X_train_selected = X_train[select_feat]
        X_val_selected = X_val[select_feat]
        select_cat_feat = [cat for cat in cat_feat if cat in select_feat]
        selected_train_pool = Pool(X_train_selected, y_train, feature_names=list(X_train_selected.columns), cat_features=select_cat_feat)
        selected_val_pool = Pool(X_val_selected, y_val, feature_names=list(X_val_selected.columns), cat_features=select_cat_feat)

        selection_model.fit(selected_train_pool, plot=False, eval_set=selected_val_pool, verbose=0)
        
        feat_num = X_train_selected.shape[1]

        eval_metrics_dict = utils.train_val_metrics(selection_model, X_train_selected, X_val_selected, y_train_actual, y_val_actual, metric=evl_metric, model_type=args.model_type) 
        metric = eval_metrics_dict[f'Train_{evl_metric}']
        logger.info(f"{feat_num} features {evl_metric} for Train: {metric}")
        metric = eval_metrics_dict[f'Val_{evl_metric}']
        logger.info(f"{feat_num} features {evl_metric} for Validation: {metric}") 

        feat_select_summary[feat_num]=metric

    logger.info("save feature selection summary dict")
    conn_string = Config.get_azure_storage_cred() #Config.get_azure_storage_cred(storage_account=Config.storage_account)['connection_string']
    container = Config.storage_container #Config.get_azure_storage_cred(storage_account=Config.storage_account)['container']
    

    utils.save_file_sf(session,feat_select_summary,'pricing',f'{args.selected_feat_file_name}_summary_{date.today().strftime("%Y%m%d")}.joblib')
    utils.save_file_azure(feat_select_summary,connection_str=conn_string,container_name=container,blob_folder='pricing',file_name=f'{args.selected_feat_file_name}_summary_{date.today().strftime("%Y%m%d")}.joblib')

    logger.info("choose the best feature number and make final feature list")
    min_mae = min(feat_select_summary.values())
    num_select_feat = int([key for key in feat_select_summary if feat_select_summary[key] == min_mae][0])
    
    selected_feat_list = list(df_feat_importance_asc.iloc[:num_select_feat,:]['feature'])
    
    final_feat_list = []
    if "Store_Code" not in selected_feat_list:
        final_feat_list.append("Store_Code")
    if "Product_Code" not in selected_feat_list:
        final_feat_list.append("Product_Code")
    #if "MonthofYear" not in selected_feat_list:
     #   final_feat_list.append("MonthofYear")
    if "Monthly_Avg_Margin_I" not in selected_feat_list:
        final_feat_list.append("Monthly_Avg_Margin_I")
    if "Monthly_Index_Max_Avg_Margin_I" not in selected_feat_list:
        final_feat_list.append("Monthly_Index_Max_Avg_Margin_I")
    if "Monthly_Index_Min_Avg_Margin_I" not in selected_feat_list:
        final_feat_list.append("Monthly_Index_Min_Avg_Margin_I")
    
    
    final_feat_list.extend(selected_feat_list)

    logger.info(f"{len(final_feat_list)} top features chosen")
    
    select_feat_list = [feat for feat in list(X_train.columns) if feat in final_feat_list]

    logger.info("save selectd feature list")
    utils.save_file_sf(session,select_feat_list,'pricing',f'{args.selected_feat_file_name}_list_{date.today().strftime("%Y%m%d")}.joblib')
    utils.save_file_azure(select_feat_list,connection_str=conn_string,container_name=container,blob_folder='pricing',file_name=f'{args.selected_feat_file_name}_list_{date.today().strftime("%Y%m%d")}.joblib')
    
    return select_feat_list


if __name__ == "__main__":
    main()


