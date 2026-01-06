module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  # ✅ RENAMED in v21
  name               = "example"
  kubernetes_version = "1.32"
  enable_cluster_creator_admin_permissions = true

  vpc_id = "vpc-02b6f225e8caca6df"

  subnet_ids = [
    "subnet-036b2bb2211e130e6",
    "subnet-0089c94753e123320",
    "subnet-0fdc82872298f30c5"
  ]


  enable_bootstrap_user_data = false
  user_data_template_path   = null
  ami_id                    = null


  eks_managed_node_groups = {
    general = {
      ami_type = "CUSTOM"

      create_launch_template     = false
      use_custom_launch_template = true

      launch_template = {
        id      = aws_launch_template.al2023_lt.id
        version = "$Latest"
      }

      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}





resource "aws_launch_template" "al2023_lt" {
  name_prefix = "example-al2023-"

  image_id      = "ami-066040dcc14399931"
  instance_type = "t3.medium"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "example-al2023-node"
    }
  }
}
