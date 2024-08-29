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
  default = ["subnet-012d74719b30ef5aa", "subnet-0dbf590095292076c"]
}

variable "eks_vpc_id" {
  type = string
  default = "vpc-0ea636f8cc198e09b"
}