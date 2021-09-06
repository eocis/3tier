terraform {
  backend "remote" {
    organization = "example-org-68bd7a"

    workspaces {
      name = "3tier"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.5"
    }
  }

  required_version = ">= 1.0.5"
}

provider "aws" {
    region = "ap-northeast-2"
}