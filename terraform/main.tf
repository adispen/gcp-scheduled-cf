provider "google" {
  project = "${var.project_id}"
  region  = "us-east1"
  zone    = "us-east1-b"
}

provider "google-beta" {
  project = "${var.project_id}"
  region  = "us-east1"
  zone    = "us-east1-b"
}

data "archive_file" "hello_world_zip" {
  type        = "zip"
  source_dir  = "${path.root}/hello_world/"
  output_path = "${path.root}/hello_world.zip"
}

resource "google_storage_bucket" "hello_world_bucket" {
  name    = "aedan_hello_world_bucket"
}

resource "google_storage_bucket_object" "hello_world_zip" {
  name   = "hello_world.zip"
  bucket = "${google_storage_bucket.hello_world_bucket.name}"
  source = "${path.root}/hello_world.zip"
}

resource "google_app_engine_application" "hello_world_scheduler_app" {
  project     = "${var.project_id}"
  location_id = "us-east1"
}

resource "google_cloudfunctions_function" "hello_world_function" {
  name                  = "hello-world-function"
  description           = "Scheduled Hello World Function"
  available_memory_mb   = 256
  source_archive_bucket = "${google_storage_bucket.hello_world_bucket.name}"
  source_archive_object = "${google_storage_bucket_object.hello_world_zip.name}"
  timeout               = 60
  entry_point           = "hello_world"
  trigger_http          = true
  runtime               = "python37"
}

resource "google_cloud_scheduler_job" "hello_world_trigger" {
  provider    = "google-beta"

  name        = "hello-world-scheduler-job"
  schedule    = "${var.schedule_cron}"

  http_target = {
    uri = "${google_cloudfunctions_function.hello_world_function.https_trigger_url}"
  }
}