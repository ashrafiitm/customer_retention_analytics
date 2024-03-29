from mage_ai.settings.repo import get_repo_path
from mage_ai.io.config import ConfigFileLoader
from mage_ai.io.config import ConfigFileLoader, ConfigKey
from mage_ai.io.google_cloud_storage import GoogleCloudStorage
from os import path
if 'data_loader' not in globals():
    from mage_ai.data_preparation.decorators import data_loader
if 'test' not in globals():
    from mage_ai.data_preparation.decorators import test

# Import necessary modules
import pandas as pd
from os import path
from google.cloud import storage

# Define function to list files in Google Cloud Storage bucket
def list_files_in_gcs_bucket(bucket_name, service_account_key_path):
    # Initialize a client using the service account key
    client = storage.Client.from_service_account_json(service_account_key_path)
    
    # Get the bucket
    bucket = client.get_bucket(bucket_name)
    
    # List all blobs (files) in the bucket
    blobs = bucket.list_blobs()
    
    # Extract file names from the blobs
    file_names = [blob.name for blob in blobs]
    
    return file_names

# Load configuration from YAML file
config = ConfigFileLoader('./ashraf-magic/io_config.yaml', 'default')
gcs = config[ConfigKey.GOOGLE_SERVICE_ACC_KEY_FILEPATH]

# Define bucket name
bucket_name = 'customer-activity-data-terraform'

# List all file names in the bucket
file_names = list_files_in_gcs_bucket(bucket_name, gcs)

olap_tables=['customer_dimension','delivery_person_dimension','location_dimension','time_dimension','fact_order']
# Filter file names for customer dimension

def filter_file_names(olap_tables, file_names):
    filtered_names = {}
    for table_name in olap_tables:
        filtered_names[table_name] = [file_name for file_name in file_names if file_name.startswith(f'transformed_data/{table_name}/part-')]
    return filtered_names

filtered_file_names=filter_file_names(olap_tables,file_names)

@data_loader
def load_from_google_cloud_storage(*args, **kwargs):
    """
    Template for loading data from a Google Cloud Storage bucket.
    Specify your configuration settings in 'io_config.yaml'.

    Docs: https://docs.mage.ai/design/data-loading#googlecloudstorage
    """
    config_path = path.join(get_repo_path(), 'io_config.yaml')
    config_profile = 'default'
    
    olap_dfs={}
    # Iterate over file paths in customer dimension
    for table_name,file_paths in filtered_file_names.items():

        # Define object key
        dfs = []
        for file_path in file_paths:

            object_key = file_path

            # Load DataFrame from Google Cloud Storage
            df = GoogleCloudStorage.with_config(ConfigFileLoader(config_path, config_profile)).load(bucket_name, object_key)
            
            # Append DataFrame to list
            dfs.append(df)
    
        # Concatenate DataFrames
        concatenated_df = pd.concat(dfs, ignore_index=True)

        olap_dfs[table_name]=concatenated_df

    return olap_dfs


@test
def test_output(output, *args) -> None:
    """
    Template code for testing the output of the block.
    """
    assert output is not None, 'The output is undefined'