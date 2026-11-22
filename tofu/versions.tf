terraform {
  required_version = ">= 1.6"
  required_providers {
    oci   = { source = "oracle/oci", version = "~> 7.0" }
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

# credentials come from ~/.oci/config (API key of the user, never stored in git)
provider "oci" {
  config_file_profile = "DEFAULT"
  region              = var.region
}
