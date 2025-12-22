
############################################
# Variables
############################################
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "eks-custom-demo"
}

variable "custom_ami_id" {
  type        = string
  description = "Custom AMI ID for nodes (must contain EKS bootstrap or equivalent)"
  default     = "ami-066040dcc14399931" # <-- replace with your AMI, e.g. ami-0abc123...
  validation {
    condition     = var.custom_ami_id != "<ID>"
    error_message = "Set var.custom_ami_id to a real AMI ID (e.g., ami-xxxxxxxx)."
  }
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "desired_size" {
  type    = number
  default = 1
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
  default     = "10.100.0.0/16"
}
