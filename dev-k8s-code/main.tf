data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false


  vpc_id     = var.eks_vpc_id
  subnet_ids = var.eks_public_subnets

 # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    disk_size      = 50
    instance_types = ["t3.medium"]
    key_name = "key"
  }

  eks_managed_node_groups = {
    blue = {
      min_size     = 0
      max_size     = 1
      desired_size = 0

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
    green = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }


  # aws-auth configmap
  # manage_aws_auth_configmap = false

  tags = {
    Environment = "prod"
    Terraform   = "true"
    Project = "MD"
  }
}

resource "helm_release" "alb-ingress-controller" {
  name = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts" 
  chart = "aws-load-balancer-controller"

  namespace = "kube-system"
  set {
    name = "clusterName"
    value = var.cluster_name
  }

  set {
    name = "serviceAccount.create"
    value = true
  }

  set {
    name = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_ingress.arn
  }

}