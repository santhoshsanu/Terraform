variable "cluster_name" {
  type = string
  default = "md-prod"
}

variable "cluster_version" {
  type = string
  default = "1.22"
}

variable "eks_public_subnets" {
  type = list(string)
  default = ["subnet-id", "subnet-id"]
}

variable "eks_vpc_id" {
  type = string
  default = "vpc-id"
}