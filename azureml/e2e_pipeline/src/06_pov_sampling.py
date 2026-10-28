import os
from pathlib import Path
import argparse
import logging


import pandas as pd
import numpy as np

from scipy import stats

import datetime
from datetime import datetime
from datetime import date

import random
from random import sample

import io
import json
import joblib
import pickle

import snowflake.connector
import snowflake.snowpark
from snowflake.snowpark.session import Session
#from snowflake.snowpark.types import PandasSeries, PandasDataFrame

import Config

import utils


def main():
    """Main function of the script."""

    # input and output arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--sf_database", type=str, help="snowflake database")
    parser.add_argument("--sf_schema", type=str, help="snowflake database schema")
    parser.add_argument("--sf_sampling_input_table", type=str, help="sampling input table name")
    parser.add_argument("--sampling_size", type=int, help="sampling size per group")
    parser.add_argument("--sf_sampling_output_table", type=str, help="sampling output table name")

    # set up logger
    logger = logging.getLogger('pricing_pov_sampling')
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

    # load sampling base data
    logger.info("load data from sampling base table")
    sampling_table_name = args.sf_sampling_input_table
    df_sample_raw = session.table(sampling_table_name).to_pandas()

    df_sample = df_sample_raw.copy()
    df_sample["Series_ID"]=df_sample["Store_Code"]+'_'+df_sample["Product_Code"]

    # split into control and treatment
    logger.info("split into control and treatment via stratified sampling")
    df_treatment = pd.DataFrame()
    
    for start in df_sample["Strat"].unique():
        n = len(df_sample[df_sample["Strat"]==start])
        n_treatment = int(np.ceil(n/2))
        df_treatment = pd.concat([df_treatment,df_sample[df_sample["Strat"]==start].sample(n=n_treatment, random_state=2024)],axis=0,ignore_index=True)

    df_control = df_sample[~df_sample["Series_ID"].isin(df_treatment["Series_ID"].unique())]

    df_treatment["Target"]=1
    df_control["Target"]=0

    df_exp = pd.concat([df_treatment,df_control],axis=0,ignore_index=True)
    df_exp = df_exp.drop(["Series_ID"],axis=1)

    # get equal number from control and treatment
    logger.info("get equal number from control and treatment")
    n_sample = min(args.sampling_size, len(df_treatment), len(df_control))
    df_exp_control = df_exp[df_exp['Target']==0].sample(n=n_sample, random_state=2024)
    df_exp_target = df_exp[df_exp['Target']==1].sample(n=n_sample, random_state=2024)

    # combine control and treatment and write back to sf
    logger.info("combine control and treatment and write back to sf")
    df_exp_sample = pd.concat([df_exp_control,df_exp_target],axis=0,ignore_index=True)
    sp_df_exp_sample = session.write_pandas(df_exp_sample, args.sf_sampling_output_table, auto_create_table=True, overwrite=True, table_type="")

    return "POV sampling completed"


if __name__ == "__main__":
    main()
