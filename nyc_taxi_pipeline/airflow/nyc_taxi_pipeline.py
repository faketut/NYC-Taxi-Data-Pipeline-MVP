import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.transfers.local_to_gcs import LocalFilesystemToGCSOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryCreateExternalTableOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator

import requests
import pandas as pd
from google.cloud import storage
from google.cloud import bigquery

# Configuration
PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "nyc-taxi-project-12345")
BUCKET_NAME = f"{PROJECT_ID}_data_lake"
BIGQUERY_DATASET = "nyc_taxi_data"
DOWNLOAD_DIR = "/tmp/nyc_taxi_data"

# Define months to download (for the MVP, we'll use 3 months of data)
MONTHS = ['2023-01', '2023-02', '2023-03']

# Default arguments for DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Define DAG
dag = DAG(
    'nyc_taxi_pipeline',
    default_args=default_args,
    description='NYC Taxi Data Pipeline',
    schedule_interval=timedelta(days=1),  # Daily
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['nyc', 'taxi', 'data-pipeline'],
)

# Task to download the NYC Taxi data
def download_taxi_data(**kwargs):
    """Download NYC Taxi data for specified months"""
    os.makedirs(DOWNLOAD_DIR, exist_ok=True)
    
    for month in MONTHS:
        year = month.split('-')[0]
        month_num = month.split('-')[1]
        url = f"https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{year}-{month_num}.parquet"
        local_path = f"{DOWNLOAD_DIR}/yellow_tripdata_{year}-{month_num}.parquet"
        
        # Download the file
        response = requests.get(url)
        with open(local_path, 'wb') as f:
            f.write(response.content)
        
        print(f"Downloaded {local_path}")
    
    return DOWNLOAD_DIR

# Task to perform basic validation and preprocessing
def preprocess_data(**kwargs):
    """Basic validation and preprocessing of downloaded data"""
    ti = kwargs['ti']
    download_dir = ti.xcom_pull(task_ids='download_taxi_data')
    
    for month in MONTHS:
        year = month.split('-')[0]
        month_num = month.split('-')[1]
        file_path = f"{download_dir}/yellow_tripdata_{year}-{month_num}.parquet"
        
        # Load the data
        df = pd.read_parquet(file_path)
        
        # Basic validation
        print(f"File {file_path}: {len(df)} rows")
        
        # Simple preprocessing (you might want to do more in a real scenario)
        # Remove rows with negative fare amounts
        df = df[df['fare_amount'] >= 0]
        
        # Save the preprocessed data
        processed_path = f"{download_dir}/processed_yellow_tripdata_{year}-{month_num}.parquet"
        df.to_parquet(processed_path, index=False)
        
        print(f"Preprocessed {processed_path}")
    
    return download_dir

# Task to create BigQuery external table
def create_external_table(**kwargs):
    """Create BigQuery external table pointing to GCS data"""
    client = bigquery.Client(project=PROJECT_ID)
    
    dataset_ref = client.dataset(BIGQUERY_DATASET)
    table_ref = dataset_ref.table("external_yellow_tripdata")
    
    # Define schema (simplified for MVP)
    schema = [
        bigquery.SchemaField("VendorID", "INTEGER"),
        bigquery.SchemaField("tpep_pickup_datetime", "TIMESTAMP"),
        bigquery.SchemaField("tpep_dropoff_datetime", "TIMESTAMP"),
        bigquery.SchemaField("passenger_count", "INTEGER"),
        bigquery.SchemaField("trip_distance", "FLOAT"),
        bigquery.SchemaField("RatecodeID", "INTEGER"),
        bigquery.SchemaField("store_and_fwd_flag", "STRING"),
        bigquery.SchemaField("PULocationID", "INTEGER"),
        bigquery.SchemaField("DOLocationID", "INTEGER"),
        bigquery.SchemaField("payment_type", "INTEGER"),
        bigquery.SchemaField("fare_amount", "FLOAT"),
        bigquery.SchemaField("extra", "FLOAT"),
        bigquery.SchemaField("mta_tax", "FLOAT"),
        bigquery.SchemaField("tip_amount", "FLOAT"),
        bigquery.SchemaField("tolls_amount", "FLOAT"),
        bigquery.SchemaField("improvement_surcharge", "FLOAT"),
        bigquery.SchemaField("total_amount", "FLOAT"),
        bigquery.SchemaField("congestion_surcharge", "FLOAT"),
    ]
    
    # Create external table config
    external_config = bigquery.ExternalConfig("PARQUET")
    
    # Set the source URIs
    external_config.source_uris = [
        f"gs://{BUCKET_NAME}/yellow_tripdata/processed_yellow_tripdata_{month}.parquet" 
        for month in MONTHS
    ]
    
    # Create the table
    table = bigquery.Table(table_ref, schema=schema)
    table.external_data_configuration = external_config
    
    # Create the table
    client.create_table(table, exists_ok=True)
    
    print(f"Created external table {PROJECT_ID}.{BIGQUERY_DATASET}.external_yellow_tripdata")

# Task to create the optimized BigQuery table
def create_optimized_table(**kwargs):
    """Create an optimized BigQuery table from the external table"""
    client = bigquery.Client(project=PROJECT_ID)
    
    # SQL to create an optimized table (partitioned and clustered)
    sql = f"""
    CREATE OR REPLACE TABLE `{PROJECT_ID}.{BIGQUERY_DATASET}.yellow_tripdata`
    PARTITION BY DATE(tpep_pickup_datetime)
    CLUSTER BY PULocationID AS
    SELECT * FROM `{PROJECT_ID}.{BIGQUERY_DATASET}.external_yellow_tripdata`
    """
    
    # Execute the query
    job = client.query(sql)
    job.result()  # Wait for the job to complete
    
    print(f"Created optimized table {PROJECT_ID}.{BIGQUERY_DATASET}.yellow_tripdata")

# Define tasks
download_task = PythonOperator(
    task_id='download_taxi_data',
    python_callable=download_taxi_data,
    dag=dag,
)

preprocess_task = PythonOperator(
    task_id='preprocess_data',
    python_callable=preprocess_data,
    dag=dag,
)

# Task to upload data to GCS
upload_to_gcs_task = LocalFilesystemToGCSOperator(
    task_id='upload_to_gcs',
    src=f"{DOWNLOAD_DIR}/processed_*.parquet",
    dst='yellow_tripdata/',
    bucket=BUCKET_NAME,
    dag=dag,
)

# Task to create external table
create_external_table_task = PythonOperator(
    task_id='create_external_table',
    python_callable=create_external_table,
    dag=dag,
)

# Task to create optimized table
create_optimized_table_task = PythonOperator(
    task_id='create_optimized_table',
    python_callable=create_optimized_table,
    dag=dag,
)

# Define task dependencies
download_task >> preprocess_task >> upload_to_gcs_task >> create_external_table_task >> create_optimized_table_task