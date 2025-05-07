# NYC Taxi Data Pipeline

This project implements an end-to-end data pipeline for analyzing NYC Yellow Taxi Trip data, including data ingestion, processing, transformation, and visualization.

## Architecture

![NYC Taxi Data Pipeline Architecture](https://i.imgur.com/placeholder.png)

The architecture consists of:

1. **Data Source**: NYC TLC Yellow Taxi Trip Data
2. **Infrastructure as Code**: Terraform for GCP resource provisioning
3. **Workflow Orchestration**: Apache Airflow for batch processing
4. **Data Lake**: Google Cloud Storage (GCS)
5. **Data Warehouse**: BigQuery with optimized tables
6. **Transformations**: dbt for data modeling and transformations
7. **Dashboard**: Looker Studio (formerly Data Studio) for visualization

## Prerequisites

- Google Cloud Platform (GCP) account
- Terraform installed locally
- Python 3.8+ installed
- Git installed

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/username/nyc-taxi-pipeline.git
cd nyc-taxi-pipeline
```

### 2. Set up GCP

1. Create a new GCP project or use an existing one
2. Enable required APIs:
   - Compute Engine API
   - BigQuery API
   - Cloud Storage API
   - IAM API

3. Create a service account with the following roles:
   - BigQuery Admin
   - Storage Admin
   - Compute Admin

4. Download the service account key (JSON) and save it to `~/.gcp/credentials.json`

5. Set environment variables:
```bash
export GOOGLE_APPLICATION_CREDENTIALS=~/.gcp/credentials.json
export GCP_PROJECT_ID=your-project-id
export GCP_REGION=us-central1
```

### 3. Deploy Infrastructure with Terraform

```bash
cd terraform

# Edit variables.tf to update project_id and region if needed

# Initialize Terraform
terraform init

# Preview the infrastructure changes
terraform plan

# Apply the infrastructure changes
terraform apply
```

Wait for the resources to be created. This will set up:
- GCS bucket for the data lake
- BigQuery dataset
- Compute Engine VM for Airflow

### 4. Set up Airflow

SSH into the Airflow VM:

```bash
gcloud compute ssh airflow-instance --project $GCP_PROJECT_ID --zone $GCP_REGION-a
```

Clone the repository on the VM and set up Airflow:

```bash
git clone https://github.com/username/nyc-taxi-pipeline.git
cd nyc-taxi-pipeline

# Initialize Airflow database
airflow db init

# Create Airflow user
airflow users create \
    --username admin \
    --password admin \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com

# Copy DAGs to Airflow dags folder
mkdir -p ~/airflow/dags
cp -r airflow/dags/* ~/airflow/dags/

# Start Airflow webserver and scheduler
airflow webserver -D
airflow scheduler -D
```

Access the Airflow web UI at `http://<VM-EXTERNAL-IP>:8080`

### 5. Set up dbt

Install dbt:

```bash
pip install dbt-bigquery
```

Set up dbt profile:

```bash
mkdir -p ~/.dbt
cp dbt/profiles.yml ~/.dbt/
```

Run dbt:

```bash
cd dbt
dbt deps
dbt run
```

### 6. Create Dashboard

1. Go to [Looker Studio](https://lookerstudio.google.com/)
2. Create a new data source connecting to BigQuery
3. Select your project, dataset (`nyc_taxi_data`), and the mart tables:
   - `mart_daily_trips`
   - `mart_location_trips`
   - `mart_hourly_trips`
4. Create a dashboard with at least two tiles:
   - One showing temporal distribution (daily trip counts)
   - One showing categorical distribution (trips by borough)

## Pipeline Execution

1. Log in to the Airflow web UI (`http://<VM-EXTERNAL-IP>:8080`)
2. Enable and trigger the `nyc_taxi_pipeline` DAG
3. Monitor the execution

The pipeline will:
1. Download NYC Yellow Taxi data for the specified months
2. Perform basic validation and preprocessing
3. Upload the data to GCS (data lake)
4. Create external and optimized tables in BigQuery
5. Run dbt transformations to create dimension and fact tables
6. Generate aggregated mart tables for the dashboard

## Project Structure

```
nyc_taxi_pipeline/
├── terraform/               # IaC for cloud resources
│   ├── main.tf              # Main Terraform configuration
│   └── variables.tf         # Terraform variables
├── airflow/                 # DAGs for orchestration
│   └── dags/
│       └── nyc_taxi_pipeline.py  # Main DAG file
├── dbt/                     # Transformations
│   ├── models/
│   │   ├── schema.yml           # dbt schema definitions
│   │   ├── dim_datetime.sql     # Datetime dimension
│   │   ├── dim_zones.sql        # Zones dimension
│   │   ├── fact_trips.sql       # Trips fact table
│   │   ├── mart_daily_trips.sql    # Daily aggregation
│   │   ├── mart_location_trips.sql # Location aggregation
│   │   └── mart_hourly_trips.sql   # Hourly aggregation
│   └── profiles.yml         # dbt connection profiles
├── scripts/                 # Utility scripts
└── README.md                # Documentation
```

## Evaluation Criteria Addressed

1. **Problem Description**: NYC Taxi data analysis for trip patterns and revenue insights
2. **Cloud**: GCP with Terraform for IaC
3. **Data Ingestion**: Batch processing with Airflow
4. **Data Warehouse**: BigQuery with partitioning and clustering
5. **Transformations**: dbt for SQL transformations
6. **Dashboard**: Looker Studio with temporal and categorical charts
7. **Reproducibility**: Detailed setup instructions provided

## Extensions

Future improvements could include:
- Streaming pipeline using Pub/Sub and Dataflow
- More sophisticated data quality checks
- Machine learning to predict busy periods or high-demand areas
- CI/CD pipeline for automated deployment
- Cost optimization of BigQuery queries

## Troubleshooting

- **Terraform errors**: Check GCP permissions and API enablement
- **Airflow connection issues**: Verify network settings and service account permissions
- **dbt failures**: Check BigQuery table access and schema compatibility
- **Dashboard connection**: Ensure BigQuery dataset sharing is properly configured

## License

This project is licensed under the MIT License - see the LICENSE file for details.