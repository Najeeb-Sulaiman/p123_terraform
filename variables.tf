variable "project" {}

variable "region" {
  default = "EU"
}

variable "zone" {
  default = "europe-west2-c"
}

variable "storage_class" {
  default = "STANDARD"
}

variable "dataset_id" {
  default = "p123_options_profitability"
}

variable "audit_table_id" {
  default = "000_audit_logs"
}