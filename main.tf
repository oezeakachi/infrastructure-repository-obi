resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

#Creating 3 subnets across different availability zones is for high availability and resilience.
resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_3_association" {
  subnet_id      = aws_subnet.subnet_3.id
  route_table_id = aws_route_table.main.id
}

resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-west-1c"
  map_public_ip_on_launch = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "eks-cluster"
  cluster_version = "1.31"

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id                   = aws_vpc.main.id
  subnet_ids               = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]
  control_plane_subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]

  eks_managed_node_groups = {
    green = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.xlarge"]

      min_size     = 1
      max_size     = 1
      desired_size = 1

      iam_role_use_name_prefix = false
      iam_role_name            = "eks-node-role"

      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        CloudWatchAgentServerPolicy        = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# IAM Role for EKS Administration with ENI cleanup permissions
resource "aws_iam_role" "eks_admin" {
  name = "eks-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "eks-admin-access"
          }
        }
      }
    ]
  })

  tags = {
    Name    = "eks-admin-role"
    Purpose = "EKS cluster administration with cleanup permissions"
  }
}

# IAM Policy for ENI and VPC management
resource "aws_iam_policy" "eks_cleanup_policy" {
  name        = "EKSCleanupPolicy"
  description = "Allows management of ENIs and VPC resources for EKS cleanup"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DetachNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach ENI cleanup policy to the admin role
resource "aws_iam_role_policy_attachment" "eks_admin_cleanup" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = aws_iam_policy.eks_cleanup_policy.arn
}

# IAM Policy to allow users to assume the eks-admin role
resource "aws_iam_policy" "assume_eks_admin_role" {
  name        = "AssumeEKSAdminRole"
  description = "Allow users to assume EKS admin role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.eks_admin.arn
      }
    ]
  })
}

# Optional: Create an IAM group for EKS admins
resource "aws_iam_group" "eks_admins" {
  name = "eks-admins"
}

# Attach the assume role policy to the group
resource "aws_iam_group_policy_attachment" "eks_admins_assume" {
  group      = aws_iam_group.eks_admins.name
  policy_arn = aws_iam_policy.assume_eks_admin_role.arn
}

# EKS Access Entry for the admin role
resource "aws_eks_access_entry" "admin_role_access" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eks_admin.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_role_policy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eks_admin.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin_role_access]
}

# Outputs
output "eks_admin_role_arn" {
  description = "IAM role ARN for EKS admin access with cleanup permissions"
  value       = aws_iam_role.eks_admin.arn
}

output "assume_role_command" {
  description = "Command to assume the EKS admin role"
  value       = "aws sts assume-role --role-arn ${aws_iam_role.eks_admin.arn} --role-session-name eks-admin-session --external-id eks-admin-access"
}

output "configure_kubectl_with_role" {
  description = "Command to configure kubectl with the admin role"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region eu-west-1 --role-arn ${aws_iam_role.eks_admin.arn}"
}