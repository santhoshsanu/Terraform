module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = "example"
  cluster_version = "1.32"

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  vpc_id = "vpc-02b6f225e8caca6df"

  subnet_ids = [
    "subnet-036b2bb2211e130e6",
    "subnet-0089c94753e123320",
    "subnet-0fdc82872298f30c5"
  ]

  # create_launch_template       = false
  # use_custom_launch_template   = true

  


  eks_managed_node_groups = {
    general = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      ami_type = "CUSTOM"
      launch_template_id      = aws_launch_template.al2023_lt.id
      launch_template_version = "$Latest"



      labels = {
        role = "general"
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}



# locals {
#   al2023_nodeadm_userdata = <<-EOF
# MIME-Version: 1.0
# Content-Type: multipart/mixed; boundary="BOUNDARY"

# --BOUNDARY
# Content-Type: application/node.eks.aws

# ---
# apiVersion: node.eks.aws/v1alpha1
# kind: NodeConfig
# spec:
#   cluster:
#     name: ${module.eks.cluster_name}
#     apiServerEndpoint: ${module.eks.cluster_endpoint}
#     certificateAuthority: ${module.eks.cluster_certificate_authority_data}

# --BOUNDARY--
# EOF
# }


resource "aws_launch_template" "al2023_lt" {
  name_prefix = "example-al2023-"

  # ✅ EKS Optimized Amazon Linux 2023 (x86_64)

  image_id = "ami-066040dcc14399931"

  

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "example-al2023-node"
    }
  }
}
