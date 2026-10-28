import os

connections = {
    'mode2': {
        'connection_params': {
            'account':"sigmahealthcare.australia-east.azure",
            'authenticator': "externalbrowser",
            'user': "dan.lozie@sigmahealthcare.com.au",
            'role': "OPS_SP_PROD_IT_data",
            'warehouse': "OPS_SP_PROD_IT_Data_WH",
            'database': "EDP_SP_PROD",
            'schema':"IT_DATA"
        },
        'template_vars': {
            "SCHEMA": "IT_DATA",
            "EDP_PRES": "EDP_PRES"
        }
    },
    'sandpit': {
        'connection_params': {
            'account':"sigmahealthcare.australia-east.azure",
            'authenticator': "externalbrowser",
            'user': "dan.lozie@sigmahealthcare.com.au",
            'role': "OPS_ANALYTICS_SANDPIT",
            'warehouse': "ANALYTICS_PBI_SANDPIT_WH",
            'database': "EDP_ANALYTICS_SANDPIT",
            'schema':"WRK"
        },
        'template_vars': {
            "SCHEMA": "WRK",
            "EDP_PRES": "EDP_PROD.PRES"
        }
    },
    'test': {
        'connection_params': {
            'account':"sigmahealthcare.australia-east.azure",
            'authenticator': "externalbrowser",
            'user': "dan.lozie@sigmahealthcare.com.au",
            'role': "OPS_ANALYTICS_TEST",
            'warehouse': "ANALYTICS_PBI_TEST_WH",
            'database': "EDP_ANALYTICS_TEST",
            'schema':"WRK"
        },
        'template_vars': {
            "SCHEMA": "WRK",
            "EDP_PRES": "EDP_PROD.PRES"
        }
    },
    'devops': {
        'connection_params': {
            'account':os.getenv('SNOWFLAKE_ACCOUNT_NAME'),
            'authenticator': os.getenv('SNOWFLAKE_AUTHENTICATOR'),
            'user': os.getenv("SNOWFLAKE_DEVOPS_USERNAME"),
            'password': os.getenv("SNOWFLAKE_DEVOPS_SECRET"),
            'role': os.getenv("SNOWFLAKE_ROLENAME"),
            'warehouse': os.getenv("SNOWFLAKE_WAREHOUSE"),
            'database': os.getenv("SNOWFLAKE_DATABASE_NAME"),
            'schema':"WRK"
        },
        'template_vars': {
            "SCHEMA": "WRK",
            "EDP_PRES": "EDP_PROD.PRES"
        }
    }
}

def get_connection():
    if os.getenv('SNOWFLAKE_DATABASE_NAME') == None:
        connection = connections['sandpit']
    else:
        connection = {
            'connection_params': {
                'account': os.getenv('SNOWFLAKE_ACCOUNT_NAME'),
                'authenticator': os.getenv('SNOWFLAKE_AUTHENTICATOR'),
                'user': os.getenv("SNOWFLAKE_DEVOPS_USERNAME"),
                'password': os.getenv("SNOWFLAKE_DEVOPS_SECRET"),
                'role': os.getenv("SNOWFLAKE_ROLENAME"),
                'warehouse': os.getenv("SNOWFLAKE_WAREHOUSE"),
                'database': os.getenv("SNOWFLAKE_DATABASE_NAME"),
                'schema':"WRK"
            },
            'template_vars': {
                "SCHEMA": "WRK",
                "EDP_PRES": "EDP_PROD.PRES"
            }
        }
        print('connecting using environment variables')
        print(connection)
    return(connection)
    
connection_params = get_connection()['connection_params']
template_vars = get_connection()['template_vars']