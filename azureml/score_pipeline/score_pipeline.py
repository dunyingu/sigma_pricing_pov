import os
from pathlib import Path
import argparse
import logging
#import requests
#import tempfile

import azureml.core
from azureml.core import Workspace, Experiment, ScriptRunConfig, RunConfiguration, Datastore
from azureml.widgets import RunDetails

from azureml.core import Environment
from azureml.core.environment import CondaDependencies

from azureml.core.compute import ComputeInstance, ComputeTarget, AmlCompute
from azureml.core.compute_target import ComputeTargetException

from azureml.pipeline.core import Pipeline
from azureml.pipeline.steps import PythonScriptStep

from src import Config 
#from src import utils

import re
import pandas as pd
from datetime import datetime


def main():
	# input and output arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--compute_instance_name", type=str, help="target compute instance name")
    parser.add_argument("--vm_size", type=str, help="compute instance size")
    parser.add_argument("--env_name", type=str, help="azure ml environment name")
    
    parser.add_argument("--sf_database", type=str, help="snowflake database")
    parser.add_argument("--sf_schema", type=str, help="snowflake database schema")

    parser.add_argument("--experiment_name", type=str, help="azure ml experiment name")

    # set up logger
    logger = logging.getLogger('pricing_pipeline_run')
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

    # get workspace
    logger.info("get workspace")
    ws = Workspace.from_config()

    # create compute instance
    logger.info("create compute instance")
    compute_instance_name=args.compute_instance_name

    try:
    	compute_target_instance = ComputeInstance(ws, compute_instance_name)
    	print("found existing compute target")
    except ComputeTargetException:
    	print("creating new compute target")
    	provisioning_config = ComputeInstance.provisioning_configuration(vm_size = args.vm_size)
    	compute_target_instance = ComputeTarget.create(ws, compute_instance_name, provisioning_config)
    
    try:
    	compute_target_instance.wait_for_completion(show_output=False,is_delete_operation=False)
    except BaseException:
    	print("Compute instance created and continue the job")

    # get environment
    logger.info("get environment")
    custom_env = Environment.get(workspace=ws, name=args.env_name)

    # configure the pipeline run
    logger.info("configure the pipeline run")
    run_config = RunConfiguration(conda_dependencies=custom_env.python.conda_dependencies)

    # define the variables
    logger.info("define variables")
    sf_database=args.sf_database
    sf_schema=args.sf_schema

    train_step1_file_path='sql/train/step1'
    train_step2_file_path='sql/train/step2'
    score_step1_file_path='sql/score/step1'
    score_step2_file_path='sql/score/step2'

    sf_feat_input_table="BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT"
    sf_feat_output_table="BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_TS_FEAT_LOG"
    
    #sf_train_table="BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_TRAIN_FEAT_LOG"
    #train_ratio=0.8
    #regression_nonzero='yes'
    #regression_mono='yes'
    #regression_model_type='regression'
    #regression_selected_feat_file_name="pricing_poc_catboost_regression_selected_feat"
    #regression_model_name="pricing_poc_catboost_regression_model"

    #classification_nonzero='no'
    #classification_mono='no'
    #classification_model_type='classification'
    #classification_selected_feat_file_name="pricing_poc_catboost_classification_selected_feat"
    #classification_model_name="pricing_poc_catboost_classification_model"

    #model_register_table_name="MODEL_REGISTRY"
    
    sf_score_input_table="BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG_PERM"
    sf_score_output_table="BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE"

    sf_sampling_input_table="BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SAMPLING"
    sampling_size=9000
    sf_sampling_output_table="BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SAMPLING_POV"

    product_recomm_output_table="SAP_NOSTRA_PRODUCT_PRICING_FOS_POC_PRICE_PERM_SCORE"
    
    run_sql_script = "01_run_sql.py"
    ts_feat_prep_script='02_pricing_ts_feat_prep.py'
    #feat_selection_script='03_feat_selection.py'
    #model_train_script='04_model_train.py'
    score_script='05_score_recomm.py'
    sampling_script='06_pov_sampling.py'
    product_recomm_script='07_product_recomm.py'

    # define steps in the pipeline
    logger.info("define steps in the pipeline")

    train_run_sql_step1_args=['--sf_database'
    						  ,sf_database
    						  ,'--sf_schema'
    						  ,sf_schema
    						  ,'--file_path'
    						  ,train_step1_file_path
    						 ]
    train_run_sql_step1=PythonScriptStep(
    									 name='train_run_sql_step1',
    									 script_name=run_sql_script,
    									 arguments=train_run_sql_step1_args,
    									 compute_target=compute_target_instance,
    									 source_directory='./src',
    									 runconfig=run_config,
    									 allow_reuse=True
    									 )
    train_run_sql_step1.validate_arguments(arguments=train_run_sql_step1_args,inputs=None,outputs=None)

    ts_feat_prep_step_args=['--sf_database'
    					    ,sf_database
    						,'--sf_schema'
    						,sf_schema
    						,'--sf_input_table'
    						,sf_feat_input_table
    						,'--sf_output_table'
    						,sf_feat_output_table
    						]
    ts_feat_prep_step=PythonScriptStep(
    								    name='ts_feat_prep_step',
    									script_name=ts_feat_prep_script,
    									arguments=ts_feat_prep_step_args,
    									compute_target=compute_target_instance,
    									source_directory='./src',
    									runconfig=run_config,
    									allow_reuse=True
    									)
    ts_feat_prep_step.validate_arguments(arguments=ts_feat_prep_step_args,inputs=None,outputs=None)

    train_run_sql_step2_args=['--sf_database'
    						  ,sf_database
    						  ,'--sf_schema'
    						  ,sf_schema
    						  ,'--file_path'
    						  ,train_step2_file_path
    						 ]
    train_run_sql_step2=PythonScriptStep(
    									 name='train_run_sql_step2',
    									 script_name=run_sql_script,
    									 arguments=train_run_sql_step2_args,
    									 compute_target=compute_target_instance,
    									 source_directory='./src',
    									 runconfig=run_config,
    									 allow_reuse=True
    									 )
    train_run_sql_step2.validate_arguments(arguments=train_run_sql_step2_args,inputs=None,outputs=None)


    #regression_feat_selection_step_args=['--sf_database'
    #						  			 ,sf_database
    #						  	         ,'--sf_schema'
    #						             ,sf_schema
    #						             ,'--sf_table'
    #						             ,sf_train_table
    #						             ,'--nonzero'
    #						             ,regression_nonzero
    #						             ,'--train_ratio'
    #						             ,train_ratio
    #						             ,'--model_type'
    #						             ,regression_model_type
    #						             ,'--selected_feat_file_name'
    #						             ,regression_selected_feat_file_name
    #						             ]
    #regression_feat_selection_step=PythonScriptStep(
    #									 name='regression_feat_selection_step',
    #									 script_name=feat_selection_script,
    #									 arguments=regression_feat_selection_step_args,
    #									 compute_target=compute_target_instance,
    #									 source_directory='./src',
    #									 runconfig=run_config,
    #									 allow_reuse=True
    #									 )
    #regression_feat_selection_step.validate_arguments(arguments=regression_feat_selection_step_args,inputs=None,outputs=None)

    #classification_feat_selection_step_args=['--sf_database'
    #						  			 ,sf_database
    #						  	         ,'--sf_schema'
    #						             ,sf_schema
    #						             ,'--sf_table'
    #						             ,sf_train_table
    #						             ,'--nonzero'
    #						             ,classification_nonzero
    #						             ,'--train_ratio'
    #						             ,train_ratio
    #						             ,'--model_type'
    #						             ,classification_model_type
    #						             ,'--selected_feat_file_name'
    #						             ,classification_selected_feat_file_name
    #						             ]
    #classification_feat_selection_step=PythonScriptStep(
    #									 name='classification_feat_selection_step',
    #									 script_name=feat_selection_script,
    #									 arguments=classification_feat_selection_step_args,
    #									 compute_target=compute_target_instance,
    #									 source_directory='./src',
    #									 runconfig=run_config,
    #									 allow_reuse=True
    #									 )
    #classification_feat_selection_step.validate_arguments(arguments=classification_feat_selection_step_args,inputs=None,outputs=None)

    #regression_model_train_step_args=['--sf_database'
    #						  			 ,sf_database
    #						  	         ,'--sf_schema'
    #						             ,sf_schema
    #						             ,'--sf_table'
    #						             ,sf_train_table
    #						             ,'--nonzero'
    #						             ,regression_nonzero
    #						             ,'--train_ratio'
    #						             ,train_ratio
    #						             ,'--model_type'
    #						             ,regression_model_type
    #						             ,'--mono'
    #						             ,regression_mono
    #						             ,'--model_file_name'
    #						             ,regression_model_name
    #						             ,'--model_register_table_name'
    #						             ,model_register_table_name
    #						             ]
    #regression_model_train_step=PythonScriptStep(
    #									 name='regression_model_train_step',
    #									 script_name=model_train_script,
    #									 arguments=regression_model_train_step_args,
    #									 compute_target=compute_target_instance,
    #									 source_directory='./src',
    #									 runconfig=run_config,
    #									 allow_reuse=True
    #									 )
    #regression_model_train_step.validate_arguments(arguments=regression_model_train_step_args,inputs=None,outputs=None)

    #classification_model_train_step_args=['--sf_database'
    #						  			 ,sf_database
    #						  	         ,'--sf_schema'
    #						             ,sf_schema
    #						             ,'--sf_table'
    #						             ,sf_train_table
    #						             ,'--nonzero'
    #						             ,classification_nonzero
    #						             ,'--train_ratio'
    #						             ,train_ratio
    #						             ,'--model_type'
    #						             ,classification_model_type
    #						             ,'--mono'
    #						             ,classification_mono
    #						             ,'--model_file_name'
    #						             ,classification_model_name
    #						             ,'--model_register_table_name'
    #						             ,model_register_table_name
    #						             ]
    #classification_model_train_step=PythonScriptStep(
    #									 name='classification_model_train_step',
    #									 script_name=model_train_script,
    #									 arguments=classification_model_train_step_args,
    #									 compute_target=compute_target_instance,
    #									 source_directory='./src',
    #									 runconfig=run_config,
    #									 allow_reuse=True
    #									 )
    #classification_model_train_step.validate_arguments(arguments=classification_model_train_step_args,inputs=None,outputs=None)

    score_run_sql_step1_args=['--sf_database'
    						  ,sf_database
    						  ,'--sf_schema'
    						  ,sf_schema
    						  ,'--file_path'
    						  ,score_step1_file_path
    						 ]
    score_run_sql_step1=PythonScriptStep(
    									 name='score_run_sql_step1',
    									 script_name=run_sql_script,
    									 arguments=score_run_sql_step1_args,
    									 compute_target=compute_target_instance,
    									 source_directory='./src',
    									 runconfig=run_config,
    									 allow_reuse=True
    									 )
    score_run_sql_step1.validate_arguments(arguments=score_run_sql_step1_args,inputs=None,outputs=None)

    score_step_args=['--sf_database'
    				 ,sf_database
    				 ,'--sf_schema'
    				 ,sf_schema
    				 ,'--sf_table'
    				 ,sf_score_input_table
    				 ,'--score_output_table_name'
    				 ,sf_score_output_table
    				]
    score_step=PythonScriptStep(
    							name='score_step',
    							script_name=score_script,
    							arguments=score_step_args,
    							compute_target=compute_target_instance,
    							source_directory='./src',
    							runconfig=run_config,
    							allow_reuse=True
    							)
    score_step.validate_arguments(arguments=score_step_args,inputs=None,outputs=None)


    score_run_sql_step2_args=['--sf_database'
    						  ,sf_database
    						  ,'--sf_schema'
    						  ,sf_schema
    						  ,'--file_path'
    						  ,score_step2_file_path
    						 ]
    score_run_sql_step2=PythonScriptStep(
    									 name='score_run_sql_step2',
    									 script_name=run_sql_script,
    									 arguments=score_run_sql_step2_args,
    									 compute_target=compute_target_instance,
    									 source_directory='./src',
    									 runconfig=run_config,
    									 allow_reuse=True
    									 )
    score_run_sql_step2.validate_arguments(arguments=score_run_sql_step2_args,inputs=None,outputs=None)
    

    sampling_step_args=['--sf_database'
                        ,sf_database
                        ,'--sf_schema'
                        ,sf_schema
                        ,'--sf_sampling_input_table'
                        ,sf_sampling_input_table
                        ,'--sampling_size'
                        ,sampling_size
                        ,'--sf_sampling_output_table'
                        ,sf_sampling_output_table
                        ]
    sampling_step=PythonScriptStep(
                                  name='pov_sampling_step',
                                  script_name=sampling_script,
                                  arguments=sampling_step_args,
                                  compute_target=compute_target_instance,
                                  source_directory='./src',
                                  runconfig=run_config,
                                  allow_reuse=True
                                )
    sampling_step.validate_arguments(arguments=sampling_step_args,inputs=None,outputs=None)


    prod_recomm_step_args=['--sf_database'
                           ,sf_database
                           ,'--sf_schema'
                           ,sf_schema
                           ,'--score_output_table_name'
                           ,product_recomm_output_table
                           ]
    prod_recomm_step=PythonScriptStep(
                                      name='recomm_product_price',
                                      script_name=product_recomm_script,
                                      arguments=prod_recomm_step_args,
                                      compute_target=compute_target_instance,
                                      source_directory='./src',
                                      runconfig=run_config,
                                      allow_reuse=True
                                      )
    prod_recomm_step.validate_arguments(arguments=prod_recomm_step_args,inputs=None,outputs=None)


    # check train job status
    train_sql_list = sorted(os.listdir(os.path.join(str(Path.cwd()),train_step2_file_path)))
    train_table = re.search(r'\d{2}_CREATE_(.*?).sql',train_sql_list[-1]).group(1)
    
    session = Config.get_sf_session(KeyVault=Config.KeyVault)
    session.use_database(args.sf_database)
    session.use_schema(args.sf_schema)

    sql_check = f"""
    select DATE_TRUNC('month',max("Insertion_Date")) "Insertion_Date"
    from {train_table}
    """

    df_month_check = session.sql(sql_check).to_pandas()
    df_month_check["Insertion_Date"]=pd.to_datetime(df_month_check["Insertion_Date"])
    month_check = df_month_check["Insertion_Date"][0]
    month_check_date = month_check.date()

    current_month_start_date = datetime.today().replace(day=1).date()
    
    # build pipeline
    logger.info("build and submit pipeline")
    
    if current_month_start_date>month_check_date:
        print("train dataset is not up to date - prepare train and score dataset in the score pipeline")
        ts_feat_prep_step.run_after(train_run_sql_step1)
        train_run_sql_step2.run_after(ts_feat_prep_step)
        score_run_sql_step1.run_after(train_run_sql_step2)
        score_step.run_after(score_run_sql_step1)
        score_run_sql_step2.run_after(score_step)
        sampling_step.run_after(score_run_sql_step2)
        prod_recomm_step.run_after(sampling_step)
    else:
        print("train dataset is already up to date - prepare score dataset only in the score pipeline")
        score_step.run_after(score_run_sql_step1)
        score_run_sql_step2.run_after(score_step)
        sampling_step.run_after(score_run_sql_step2)
        prod_recomm_step.run_after(sampling_step)

    score_pipeline = Pipeline(workspace=ws, steps=[prod_recomm_step])
    score_pipeline.validate()
    score_pipeline_run = Experiment(ws, args.experiment_name).submit(score_pipeline, regenerate_outputs=False)
    
    # run the pipleine
    logger.info("pipeline is running")
    #RunDetails(score_pipeline_run).show()
    try:
        score_pipeline_run.wait_for_completion(show_output=False, raise_on_error=True)
    except BaseException:
        print("Errors - proceed to delete the compute instance")

    # delete the compute instance
    logger.info("delete the compute instance")
    compute_target_instance.delete(wait_for_completion=False, show_output=False)

    return 'Score pipeline run is completed'




if __name__ == "__main__":
    main()




