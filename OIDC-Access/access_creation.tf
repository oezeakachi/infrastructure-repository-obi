terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# 1. Get the OIDC Provider's TLS certificate thumbprint
data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"
}

# 2. Create the AWS IAM OIDC Provider
resource "aws_iam_openid_connect_provider" "github_oidc" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
}

# 3. IAM Policy Document for the GitHub Actions Trust Relationship
data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_oidc.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # 🚨 CRITICAL: Restrict role assumption to a specific repository and branch (e.g., 'main')
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Change 'ref:refs/heads/main' to '*' to allow all branches
      values   = ["repo:oezeakachi/infrastructure-repository-obi:*"] 
    }
  }
}

# 4. IAM Role for GitHub Actions (Deployer Role)
resource "aws_iam_role" "github_actions_role" {
  name               = "github-actions-eks-deploy-role"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

# 5. Attach the required EKS Admin Policy
resource "aws_iam_role_policy_attachment" "github_actions_eks_admin" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 6. Output the ARN for use in the workflow
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume"
  value       = aws_iam_role.github_actions_role.arn
}