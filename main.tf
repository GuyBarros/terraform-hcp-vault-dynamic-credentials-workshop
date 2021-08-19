
terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "emea-se-playground-2019"
    workspaces {
      name = "GUY-Instruqt-HCP-Vault"
    }
  }
}

provider "aws" {
  #  region  = var.primary_region
  #  alias   = "primary"
  default_tags {
    tags = local.common_tags
  }
    }
