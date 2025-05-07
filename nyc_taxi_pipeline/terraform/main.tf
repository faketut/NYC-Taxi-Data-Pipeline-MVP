terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Create GCS bucket for data lake
resource "google_storage_bucket" "data_lake_bucket" {
  name     = "${var.project_id}_data_lake"
  location = var.region
  
  # Optional settings
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  
  force_destroy = true
  
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30 # days
    }
  }
}

# Create BigQuery dataset
resource "google_bigquery_dataset" "nyc_taxi_dataset" {
  dataset_id = "nyc_taxi_data"
  location   = var.region
  
  delete_contents_on_destroy = true
}

# Create compute instance for Airflow (small VM for MVP)
resource "google_compute_instance" "airflow_vm" {
  name         = "airflow-instance"
  machine_type = "e2-standard-2"
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 30
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOF
    sudo apt-get update
    sudo apt-get install -y python3-pip
    sudo pip3 install apache-airflow
    sudo pip3 install google-cloud-storage
    sudo pip3 install google-cloud-bigquery
    sudo pip3 install pandas
  EOF

  service_account {
    scopes = ["cloud-platform"]
  }
}