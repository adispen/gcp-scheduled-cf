# Deploying Scheduled Cloud Functions with Terraform

Whether you're managing key rotation, creating monitoring alerts, or policing expiration policies on your
 resources; you will probably look to scheduled serverless functions for a cheap and scalable
 solution.  While investigating the feasibility of using Google Cloud Functions to manage project expiration
 in Google Cloud Platform it became apparent that this kind of functionality was still fairly immature.
 With the release of the new Google 2.0.0 Terraform Provider though, running a Cloud Function on a 
 given cron schedule has become just a bit easier.
 
### GCP 2.0.0 Terraform Provider

On its [February 12th 2018 release](https://github.com/terraform-providers/terraform-provider-google/blob/master/CHANGELOG.md#200-february-12-2019), the newest version of the GCP provider for Terraform included some 
 interesting and undocumented changes, including the `google_cloudfunctions_function` resource in the 
 `google-beta` branch.  Poking through some of the source code and tests
 allows us to find some documentation on how to get started.
 
### Setting Up

Creating a Cloud Function in Terraform starts with managing your source code.  There are a few different
 methods, including pulling from an external repo, but for this example I'll be setting up my environment
 so Terraform can create a `.zip` archive.  The folder structure below is what I used for the code samples in the
 rest of this demo.
 ```
 terraform/
 ├── hello_world/
 │   └── main.py
 ├── main.tf
 └── variables.tf
 ```
 With this setup our Terraform code will create a compressed archive of the `hello_world` directory, upload it to a bucket, 
 and pass that object reference to the Cloud Function.  It is worth noting that for a Cloud Function
 with a Python runtime the file that contains the entrypoint must be named `main.py`.  
 
 The corresponding Terraform code for this approach:
 ```hcl-terraform
# zip up our source code
data "archive_file" "hello_world_zip" {
  type        = "zip"
  source_dir  = "${path.root}/hello_world/"
  output_path = "${path.root}/hello_world.zip"
}

# create the storage bucket
resource "google_storage_bucket" "hello_world_bucket" {
  name   = "hello_world_bucket"
}

# place the zip-ed code in the bucket
resource "google_storage_bucket_object" "hello_world_zip" {
  name   = "hello_world.zip"
  bucket = "${google_storage_bucket.hello_world_bucket.name}"
  source = "${path.root}/hello_world.zip"
}
```

### Creating the Cloud Function
 Now that our code is in the cloud, we need to create the Cloud Function itself.  At the time of writing
 GCP support for Python Cloud Functions is in beta and only supports a `python3.7` runtime.
 ```hcl-terraform
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
```
 Here we make sure to enable the HTTP trigger for the Cloud Function since Cloud Scheduler requires an
 endpoint for scheduling.
 
### Cloud Scheduler
 With our Cloud Function defined, we now need to define its trigger mechanism.
 ```hcl-terraform
provider "google-beta" {
  project = "${var.project_id}"
  region  = "us-east1"
  zone    = "us-east1-b"
}

# create an app engine application for your scheduler
resource "google_app_engine_application" "hello_world_scheduler_app" {
  project     = "${var.project_id}"
  location_id = "us-east1"
}

resource "google_cloud_scheduler_job" "hello_world_trigger" {
  provider    = "google-beta"

  name        = "hello-world-scheduler-job"
  schedule    = "${var.schedule_cron}"

  http_target = {
    uri = "${google_cloudfunctions_function.hello_world_function.https_trigger_url}"
  }
}
```
 At the time of writing the `google_cloud_scheduler_job` resource is only available in the `google-beta`
 provider, so we need to make sure to include it in the resource definition.  Note that if you already have
 any App Engine resources in a particular zone you must also specify that region and zone here, since Cloud Scheduler
 utilizes App Engine.
 
 The schedule argument accepts any valid cron style string.  For example `* * * * *` would create a trigger 
 that fires on every minute.  Passing these in as a variable can allow you to better modularize this particular
 resource.
 
#### Further Reading
* [Google Cloud Function Terraform Resource](https://www.terraform.io/docs/providers/google/r/cloudfunctions_function.html)
* [Google Cloud Scheduler Job Terraform Resource](https://www.terraform.io/docs/providers/google/r/cloud_scheduler_job.html)
* [Source code for this lab](https://github.com/adispen/gcp-scheduled-cf)