terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.15"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
