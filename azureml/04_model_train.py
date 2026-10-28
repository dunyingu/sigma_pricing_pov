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

import optuna
from optuna.samplers import TPESampler
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

    parser.add_argument("--nonzero", type=str, default='no', help="only use non-zero orders")
    parser.add_argument("--train_ratio", type=float, default=0.8, help="percentage of dataset used to train models")
    #parser.add_argument("--train_start_date", type=str, help="train data start date")
    #parser.add_argument("--train_end_date", type=str, help="train data cutoff date")
    #parser.add_argument("--val_start_date", type=str, help="val data start date")
    #parser.add_argument("--val_end_date", type=str, help="val data cutoff date")

    parser.add_argument("--model_type", type=str, help="classification or regression")

    #parser.add_argument("--selected_feat_file_name", type=str, help="selected feat list") # follow name convention, example: pricing_poc_catboost_regression_selected_feat; pricing_poc_catboost_classification_selected_feat
    parser.add_argument("--mono", type=str, help="set mono features")

    parser.add_argument("--model_file_name", type=str, help="output model file name") # follow name convention, example: pricing_poc_catboost_regression_model; pricing_poc_catboost_classification_model
    parser.add_argument("--model_register_table_name", type=str, help="snowflake model register table name")


    # set up logger
    logger = logging.getLogger('prcing_model_train')
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
    
    logger.info("load selected feat list")
    
    sql_files = """
    --list @MODELS/pricing
    select distinct METADATA$FILENAME "filename", METADATA$FILE_LAST_MODIFIED "last_modified"
    from @MODELS/pricing
    """
    df_files = session.sql(sql_files).to_pandas()
    list_name_check = f'_{args.model_type}_selected_feat_list'
    at_list = df_files[df_files.filename.str.contains(list_name_check)]
    at_list = at_list[at_list['last_modified']==max(at_list.last_modified)]
    file_name = list(at_list['filename'])[0].split('/')[-1]

    select_feat_list = list(utils.get_file_sf(session, file_path='pricing', file_name=file_name, tmppath='./tmp'))
    
    conn_string = Config.get_azure_storage_cred() #Config.get_azure_storage_cred(storage_account=Config.storage_account)['connection_string']
    container = Config.storage_container #Config.get_azure_storage_cred(storage_account=Config.storage_account)['container']
    #select_feat_list = list(utils.get_file_azure(connection_str=conn_string,container_name=container,blob_folder='pricing',file_name=file_name))

    logger.info("select features")

    feat_list = [feat for feat in list(df_feat.columns) if feat in select_feat_list]

    X_train = X_train[feat_list]
    X_val = X_val[feat_list ]
    
    select_cat_feat = [cat for cat in cat_feat if cat in select_feat_list ]


    if args.model_type == 'regression':
        y_train = df_train[log_target] #target
        y_val = df_val[log_target] #target

        y_train_actual = df_train[target]
        y_val_actual = df_val[target]
    else:
        y_train = df_train[label]
        y_val = df_val[label]

        y_train_actual = df_train[label]
        y_val_actual = df_val[label]

    train_pool = Pool(X_train, y_train, feature_names=list(X_train.columns), cat_features=select_cat_feat)
    val_pool = Pool(X_val, y_val, feature_names=list(X_val.columns), cat_features=select_cat_feat)

    if args.mono == 'yes':
        mono_list = [0] * (X_train.shape[1])
        mono_list[list(X_train.columns).index("Monthly_Avg_Margin_I")]=-1
        mono_list[list(X_train.columns).index("Monthly_Index_Max_Avg_Margin_I")]=-1
        mono_list[list(X_train.columns).index("Monthly_Index_Min_Avg_Margin_I")]=-1

    def objective(trial):
        params_dist = { 
              "iterations": trial.suggest_int('iterations', 500, 2000)
              ,"depth": trial.suggest_int('depth', 3, 9)
              ,"l2_leaf_reg": trial.suggest_float('l2_leaf_reg', 1, 10)
              ,"learning_rate":  trial.suggest_float('learning_rate', 0.01, 0.1)
              ,"colsample_bylevel":  trial.suggest_float('colsample_bylevel', 0.2, 0.8)
              ,"random_strength": trial.suggest_int('random_strength', 0, 6)
              ,"max_ctr_complexity": trial.suggest_int('max_ctr_complexity', 0, 3)
              ,'boosting_type': trial.suggest_categorical('boosting_type', ['Ordered', 'Plain'])
              ,"bootstrap_type": trial.suggest_categorical("bootstrap_type", ["Bayesian", "Bernoulli", "MVS"]),
            }

        if params_dist["bootstrap_type"] == "Bayesian":
            params_dist["bagging_temperature"] = trial.suggest_float("bagging_temperature", 0, 10)
        elif params_dist["bootstrap_type"] == "Bernoulli":
            params_dist["subsample"] = trial.suggest_float("subsample", 0.1, 1)

        if args.model_type == 'regression':
            loss_function = 'RMSE'
            evl_metric = 'MAE'
            if args.mono == 'yes':
                model = CatBoostRegressor(**params_dist
                                          ,loss_function=loss_function
                                          ,eval_metric=evl_metric
                                          ,monotone_constraints=mono_list
                                          ,random_seed=2024
                                          ,allow_writing_files=False
                                          ,train_dir=None
                                          )
            else:
                model = CatBoostRegressor(**params_dist
                                          ,loss_function=loss_function
                                          ,eval_metric=evl_metric
                                          #,monotone_constraints=mono_list
                                          ,random_seed=2024
                                          ,allow_writing_files=False
                                          ,train_dir=None
                                          )
        elif args.model_type == 'classification':
            loss_function = 'CrossEntropy'
            evl_metric = 'AUC'
            if args.mono == 'yes':
                model = CatBoostClassifier(**params_dist
                                           ,loss_function=loss_function
                                           ,eval_metric=evl_metric
                                           ,monotone_constraints=mono_list
                                           ,random_seed=2024
                                           ,allow_writing_files=False
                                           ,train_dir=None
                                           )
            else:
                model = CatBoostClassifier(**params_dist
                                           ,loss_function=loss_function
                                           ,eval_metric=evl_metric
                                           #,monotone_constraints=mono_list
                                           ,random_seed=2024
                                           ,allow_writing_files=False
                                           ,train_dir=None
                                           )

        model.fit(train_pool, plot=False, eval_set=val_pool, verbose=0)

        #X = pd.concat([X_train,X_val],axis=0,ignore_index=True)
        #y = pd.concat([y_train_actual,y_val_actual],axis=0,ignore_index=True)


        if args.model_type == 'regression':
            y_pred_log = model.predict(X_val)
            y_pred = np.exp(y_pred_log)-1
        else:
            y_pred = model.predict(X_val)

        return eval_metric(np.array(y_val_actual), np.clip(y_pred,a_min=0,a_max=None), evl_metric)[0]


    logger.info("hyperparameter tunning")
    sampler = TPESampler(seed=random.randint(1,2024))
    if args.model_type == 'regression':
        study = optuna.create_study(direction='minimize', sampler=sampler)
    else:
        study = optuna.create_study(direction='maximize', sampler=sampler)
    
    study.optimize(objective, n_trials=10)

    logger.info("train model using best hyperparameters")
    params = study.best_params

    if args.model_type == 'regression':
        loss_function = 'RMSE'
        evl_metric = 'MAE'
        if args.mono == 'yes':
            opt_model = CatBoostRegressor(**params 
                                          ,loss_function=loss_function
                                          ,eval_metric=evl_metric
                                          ,monotone_constraints=mono_list
                                          ,random_seed=2024
                                          ,allow_writing_files=False
                                          ,train_dir=None
                                          )
        else:
            opt_model = CatBoostRegressor(**params 
                                          ,loss_function=loss_function
                                          ,eval_metric=evl_metric
                                          #,monotone_constraints=mono_list
                                          ,random_seed=2024
                                          ,allow_writing_files=False
                                          ,train_dir=None
                                          )
    elif args.model_type == 'classification':
        loss_function = 'CrossEntropy'
        evl_metric = 'AUC'
        if args.mono == 'yes':
            opt_model = CatBoostClassifier(**params 
                                          ,loss_function=loss_function
                                          ,eval_metric=evl_metric
                                          ,monotone_constraints=mono_list
                                          ,random_seed=2024
                                          ,allow_writing_files=False
                                          ,train_dir=None
                                          )
        else:
            opt_model = CatBoostClassifier(**params 
                                          ,loss_function=loss_function
                                          ,eval_metric=evl_metric
                                          #,monotone_constraints=mono_list
                                          ,random_seed=2024
                                          ,allow_writing_files=False
                                          ,train_dir=None
                                          )

    X = pd.concat([X_train,X_val],axis=0,ignore_index=True)
    y = pd.concat([y_train,y_val],axis=0,ignore_index=True)
    fit_pool = Pool(X, y, feature_names=list(X.columns), cat_features=select_cat_feat)
    opt_model.fit(fit_pool, plot=False, verbose=0)
    #opt_model.fit(train_pool, plot=False, eval_set=val_pool, verbose=0)

    logger.info("save the model")
    utils.save_file_sf(session,opt_model,'pricing',f'{args.model_file_name}_{date.today().strftime("%Y%m%d")}.joblib')
    utils.save_file_azure(opt_model,connection_str=conn_string,container_name=container,blob_folder='pricing',file_name=f'{args.model_file_name}_{date.today().strftime("%Y%m%d")}.joblib')

    logger.info("get feature importance")
    df_feat_importance= pd.DataFrame(zip(list(X.columns), opt_model.feature_importances_), columns=['feature', 'importance'])#.set_index('feature')
    df_feat_importance_desc = df_feat_importance.sort_values(by=['importance'], ascending=False)

    logger.info("register the model in a snowflake table")
    df_model_register = pd.DataFrame()
    df_model_register['Model_Name']=[f'{args.model_file_name}_{date.today().strftime("%Y%m%d")}.joblib']
    df_model_register['Project']=['Pricing']
    df_model_register['Description']=[f'pricing {args.model_type} model trained using optimal feature set and hyperparameters on dataset from {train_start_date} to {val_end_date}']
    df_model_register['Train_Date']=[date.today().strftime("%Y-%m-%d")]
    df_model_register['Stage_Location']=[os.path.join('@MODELS/pricing/',f'{args.model_file_name}_{date.today().strftime("%Y%m%d")}.joblib')]
    df_model_register['Hyperparameters']=[params]
    df_model_register['Metrics']=[utils.train_val_metrics(opt_model, X_train, X_val, y_train_actual, y_val_actual, evl_metric, model_type=args.model_type)]
    df_model_register['Feature_Importance']=[df_feat_importance_desc.iloc[:10,:].set_index('feature')['importance'].to_dict()]
    
    sp_df_model_register = session.write_pandas(df_model_register, args.model_register_table_name, auto_create_table=True, overwrite=False, table_type="")

    return 'model successfully traind and registered'



if __name__ == "__main__":
    main()