import os
from azure.identity import DefaultAzureCredential,ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient
from azure.core.exceptions import ClientAuthenticationError
import urllib.parse

#import snowflake.connector
#import snowflake.snowpark
from snowflake.snowpark.session import Session


KeyVault = 'kv-dataplatform-dev' #'kv-dataplatform-produ'

client_id = os.environ.get('DEFAULT_IDENTITY_CLIENT_ID')
print(client_id)
credential = ManagedIdentityCredential(client_id=client_id)
print(credential)

KVUri = f'https://{KeyVault}.vault.azure.net'

try:
    credential.get_token(KVUri)
    print(credential.get_token(KVUri))
except ClientAuthenticationError as ex:
    print(ex.message)

client = SecretClient(vault_url=KVUri, credential=credential)
print(client)


def get_sf_session(KeyVault=KeyVault) -> Session:

    SecretName = 'SnowflakeConnStringAnalytics'

    retrieved_secret = client.get_secret(SecretName)
    secret_connstring = retrieved_secret.value
    secret_parse = urllib.parse.parse_qs(secret_connstring.split('?')[1])

    sf_connection_params = dict()
    sf_connection_params['account']='sigmahealthcare.australia-east.azure'

    for k,v in secret_parse.items():
        sf_connection_params[k]=v[0]

    session = Session.builder.configs(sf_connection_params).create()

    return session


storage_account = 'advancedanalytics'
storage_container = 'snowflakeml'

def get_azure_storage_cred(): #(storage_account=storage_account)

    SecretName = 'StConnStringAdvancedAnalytics'

    retrieved_secret = client.get_secret(SecretName)
    secret_connstring = retrieved_secret.value

    return secret_connstring

