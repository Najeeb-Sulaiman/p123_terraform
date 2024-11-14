terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

# Define the required provider
provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

# Create a bucket
resource "google_storage_bucket" "default" {
  name          = "p123_jlr_vehicle_data"
  location      = "europe-west2"
  storage_class = var.storage_class

  uniform_bucket_level_access = true
}

# Create a bucket
resource "google_storage_bucket" "bucket" {
  name          = "jlr_vehicle_data"
  location      = var.region
  storage_class = var.storage_class

  uniform_bucket_level_access = true
}

# Create a Dataset
resource "google_bigquery_dataset" "dataset" {
  dataset_id  = var.dataset_id
  description = "Dataset for the vehicle options profitability"
  location    = var.region

  labels = {
    epic_id = "p123"
  }
}

# Create a Service Account
resource "google_service_account" "sa" {
  account_id   = "dataform-connect"
  display_name = "Service account for Dataform"
}

# Assign BigQuery Data Editor role
resource "google_project_iam_member" "bigquery_data_editor" {
  project = var.project
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

# Assign Secret Manager Secret Accessor role
resource "google_project_iam_member" "secretmanager_secret_accessor" {
  project = var.project
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

# Assign Service Account Token Creator role
resource "google_project_iam_member" "service_account_token_creator" {
  project = var.project
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

# Assign BigQuery Job User role
resource "google_project_iam_member" "bigquery_job_user" {
  project = var.project
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

# Cloud function provisioning
# Upload function code to GCS bucket
resource "google_storage_bucket_object" "archive" {
  name   = "main.zip"
  bucket = google_storage_bucket.bucket.name
  source = "function-source/main.zip"
}

# Cloud function
resource "google_cloudfunctions2_function" "function" {
  name        = "p123_options_profitability"
  description = "Function to load csv data from GCS to Bigquery"
  location    = "europe-west2"

  build_config {
    runtime = "python310"
    entry_point = "load_data_to_bigquery"  # Set the entry point 
    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name
        object = google_storage_bucket_object.archive.name
      }
    }
  }

  service_config {
    min_instance_count = 0
    max_instance_count = 5
    available_memory   = "256M"
    timeout_seconds    = 60
    environment_variables = {
    PROJECT_ID     = var.project
    DATASET_ID     = var.dataset_id
    AUDIT_TABLE_ID = var.audit_table_id
  }
  ingress_settings = "ALLOW_INTERNAL_ONLY"
  all_traffic_on_latest_revision = true
  service_account_email = "819650252384-compute@developer.gserviceaccount.com"
  }


  # Define the trigger for GCS bucket changes
  event_trigger {
    event_type = "google.cloud.storage.object.v1.finalized"
    event_filters {
      attribute = "bucket"
      value = google_storage_bucket.default.name
    }
  }
}