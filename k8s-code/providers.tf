############################################
# main.tf — Minimal EKS + Node Group (CUSTOM AMI)
# Fixed multi-arg single-line blocks
############################################

terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}


provider "aws" {
  region = var.region
}
