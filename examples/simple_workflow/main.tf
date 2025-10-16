/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

data "google_project" "project" {
  project_id = var.project_id
}

data "google_compute_default_service_account" "default" {
  project = var.project_id
}

resource "random_string" "string" {
  length  = 8
  lower   = true
  upper   = false
  special = false
  numeric = false
}

module "gcs_buckets" {
  source          = "terraform-google-modules/cloud-storage/google"
  version         = "~> 3.4.0"
  location        = "us-central1"
  project_id      = var.project_id
  names           = ["wf-bucket"]
  prefix          = random_string.string.result
  set_admin_roles = true
  admins          = ["serviceAccount:${data.google_compute_default_service_account.default.email}"]
  force_destroy   = { wf-bucket = true }
}

module "standalone_workflow" {
  source  = "../../modules/simple_workflow"

  project_id            = var.project_id
  workflow_name         = "standalone-workflow"
  region                = "us-central1"
  service_account_email = data.google_compute_default_service_account.default.email
  service_account_create = true
  workflow_source = <<-EOF
  # This is a sample workflow that simply reads wikipedia
  # Note that $$ is needed for Terraform

  main:
      steps:
      - readWikipedia:
          call: http.get
          args:
              url: https://en.wikipedia.org/w/api.php
              query:
                  action: opensearch
                  search: GoogleCloudPlatform
          result: wikiResult
      - returnOutput:
              return: $${wikiResult.body[1]}
EOF
}
