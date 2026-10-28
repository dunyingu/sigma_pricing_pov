import os
from pathlib import Path
import argparse
import logging

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
    parser.add_argument("--file_path", type=str, help="sql file path")

    # set up logger
    logger = logging.getLogger('pricing_feature_creation')
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
    logger.info("run sql files in the designated folders to generate features")

    #sql_list = []
    for sql_file in sorted(os.listdir(os.path.join(str(Path.cwd()),args.file_path))):
        if sql_file[0].isdigit() & sql_file.endswith('.sql'):
            sql_qry=utils.read_sql(args.file_path,sql_file)
            #sql_list.append(sql_qry)
            logger.info(f'running sql: {sql_file}')
            df = session.sql(sql_qry).collect() #session.sql(sql_qry)
            logger.info(f'{sql_file} run completed')
        else:
            continue

    return 'sql run completed'


if __name__ == "__main__":
    main()