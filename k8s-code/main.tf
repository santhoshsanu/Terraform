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

############################################
# Variables
############################################
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "eks-custom-ami-demo"
}

variable "custom_ami_id" {
  type        = string
  description = "Custom AMI ID for nodes (must contain EKS bootstrap or equivalent)"
  default     = "ami-0e2635e5701f88a12" # <-- replace with your AMI, e.g. ami-0abc123...
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
  default = 2
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

provider "aws" {
  region = var.region
}

############################################
# VPC (simple: 2 public subnets)
############################################
data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1) # 10.100.1.0/24
  availability_zone       = data.aws_availability_zones.azs.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "${var.cluster_name}-public-a"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2) # 10.100.2.0/24
  availability_zone       = data.aws_availability_zones.azs.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "${var.cluster_name}-public-b"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}


############################################
# Security Groups (no cross-refs inside)
############################################

# Cluster SG (for control plane ENIs)
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  vpc_id      = aws_vpc.vpc.id
  description = "EKS cluster SG"

  # no ingress here — added via aws_security_group_rule below

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-cluster-sg" }
}

# Node SG
resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  vpc_id      = aws_vpc.vpc.id
  description = "EKS nodes SG"

  # node-to-node
  ingress {
    description = "Node-to-node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # no cluster->nodes ingress here — added via aws_security_group_rule below

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-nodes-sg" }
}




############################################
# IAM (cluster and nodes)
############################################
data "aws_iam_policy_document" "assume_cluster" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.assume_cluster.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

data "aws_iam_policy_document" "assume_nodes" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nodes" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.assume_nodes.json
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_ro" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

############################################
# EKS Cluster
############################################
resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  # Optionally pin version:
  # version = "1.30"

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,
    aws_iam_role_policy_attachment.eks_service
  ]
}

############################################
# Launch Template (uses your custom AMI)
############################################
locals {
  user_data_b64 = base64encode(<<-EOT
    #!/bin/bash
    set -xe
    /etc/eks/bootstrap.sh ${var.cluster_name} \
      --kubelet-extra-args "--node-labels=node.kubernetes.io/lifecycle=normal"
  EOT
  )
}

resource "aws_launch_template" "lt" {
  name_prefix = "${var.cluster_name}-lt-"
  image_id    = var.custom_ami_id



  vpc_security_group_ids = [aws_security_group.nodes.id]
  user_data              = local.user_data_b64

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                                        = "${var.cluster_name}-node"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  }
}

############################################
# Managed Node Group (CUSTOM AMI)
############################################
resource "aws_eks_node_group" "ng" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  ami_type = "CUSTOM" # required with custom AMI + launch template

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  instance_types = var.instance_types
  capacity_type  = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  depends_on = [aws_eks_cluster.cluster]
}

############################################
# Outputs
############################################
output "cluster_name" {
  value = aws_eks_cluster.cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}

output "nodegroup_status" {
  value = aws_eks_node_group.ng.status
}
