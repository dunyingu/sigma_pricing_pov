import Config

import os
from pathlib import Path
#import argparse
#import logging

import re

#import snowflake.connector
#import snowflake.snowpark
from snowflake.snowpark.session import Session
#from snowflake.snowpark.types import PandasSeries, PandasDataFrame

import pandas as pd
import numpy as np

import datetime
from datetime import datetime
from datetime import date

#import sklearn
#from sklearn.preprocessing import OrdinalEncoder#, LabelEncoder, OneHotEncoder, MinMaxScaler, PowerTransformer
#from sklearn.impute import SimpleImputer
#from sklearn.preprocessing import MinMaxScaler
#from sklearn.compose import ColumnTransformer
#from sklearn.pipeline import Pipeline
from sklearn.metrics import mean_squared_error, mean_squared_log_error, mean_absolute_error, roc_auc_score


import catboost
from catboost import Pool, CatBoostRegressor, CatBoostClassifier, EShapCalcType, EFeaturesSelectionAlgorithm
from catboost.utils import eval_metric

import io
import json
import joblib
import pickle

from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobClient




def read_sql (sql_file_path,sql_file_name):
    if os.path.exists(os.path.join(str(Path.cwd()),sql_file_path,sql_file_name)):
        sql_file = open(os.path.join(str(Path.cwd()),sql_file_path,sql_file_name),'r')
        sql_list = sql_file.readlines()
        
        sql_qry = ''.join(sql_list)
        sql_qry = re.sub('/\\*(.*\n){1,}\\*/|/\\*.*\\*/|--.*\n','',sql_qry)
    else:
        print('Cannot find file ', sql_file_name, '. Please check file name')
    
    return sql_qry


def train_val_metrics(model, X_train, X_val, y_train, y_val,metric,model_type='regression'):
    y_train_pred = model.predict(X_train)
    y_val_pred = model.predict(X_val)
    
    if model_type=='regression':
        y_train_pred = np.exp(y_train_pred)-1
        y_val_pred = np.exp(y_val_pred)-1
    
    metrics_dict = {}

    metrics_dict[f'Train_{metric}']=eval_metric(np.array(y_train), np.clip(y_train_pred,a_min=0,a_max=None), metric)[0]
    metrics_dict[f'Val_{metric}']=eval_metric(np.array(y_val), np.clip(y_val_pred,a_min=0,a_max=None), metric)[0]

    #if metric=='MAE':
     #   metrics_dict[f'Train_{metric}']=mean_absolute_error(np.array(y_train), np.clip(y_train_pred,a_min=0,a_max=None))
     #   metrics_dict[f'Val_{metric}']=mean_absolute_error(np.array(y_val), np.clip(y_val_pred,a_min=0,a_max=None))
    
    #if metric=='AUC':
     #   metrics_dict[f'Train_{metric}']=roc_auc_score(np.array(y_train), y_train_pred)
     #   metrics_dict[f'Val_{metric}']=roc_auc_score(np.array(y_val), y_val_pred)
    
    return metrics_dict



def save_file_sf(session: Session, obj, file_path, file_name):
    #input_stream = io.BytesIO()
    #joblib.dump(obj, input_stream)
    #session._conn._cursor.upload_stream(input_stream, os.path.join(file_path,file_name))
    joblib.dump(obj, file_name)
    session.file.put(file_name, os.path.join('@MODELS', file_path), auto_compress=False, overwrite=True) 

    return f"{file_name} saved to snowflake stage"


def get_file_sf(session: Session, file_path, file_name, tmppath='./tmp'):
    session.file.get(os.path.join('@MODELS', file_path, file_name), tmppath) #session.file.get(f'@MODELS/{file_path}/{file_name}', tmppath)
    obj_file = os.path.join(tmppath, f'{file_name}')
    obj = joblib.load(obj_file)
    return obj


def save_file_azure(obj,connection_str,container_name,blob_folder,file_name):

    joblib.dump(obj, file_name)

    blob = BlobClient.from_connection_string(conn_str=connection_str,
                                             container_name=container_name, 
                                             blob_name=os.path.join(blob_folder,file_name))

    with open(file_name, "rb") as data:
        blob.upload_blob(data,overwrite=True)

    return f"{file_name} saved to azure blob storage"


def get_file_azure(connection_str,container_name,blob_folder, file_name):

    obj_file = os.path.join('./tmp', file_name)
    
    blob = BlobClient.from_connection_string(conn_str=connection_str,
                                             container_name=container_name, 
                                             blob_name=os.path.join(blob_folder,file_name))

    with open(file=obj_file, mode="wb") as download_file:
        blob_data = blob.download_blob()
        blob_data.readinto(download_file)

    obj = joblib.load(obj_file)
    return obj
