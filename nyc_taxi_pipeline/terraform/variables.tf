variable "project_id" {
  description = "Your GCP Project ID"
  type        = string
  default     = "nyc-taxi-project-12345" # Replace with your actual project ID
}

variable "region" {
  description = "Region for GCP resources"
  type        = string
  default     = "us-central1"
}