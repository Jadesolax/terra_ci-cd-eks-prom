provider "aws" {
  region = var.aws_region
}

module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.6"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.30"

  vpc_id          = var.vpc_id
  subnets         = var.subnets

  enable_irsa = true  # Enable IAM Roles for Service Accounts (IRSA)

  node_groups = {
    eks_nodes = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1
      instance_type    = "t3.medium"
    }
  }
}

module "vpc_cni" {
  source  = "terraform-aws-modules/eks/aws//modules/vpc-cni"
  version = "20.31.6"

  cluster_name = module.eks_cluster.cluster_name

  # Attach the required IAM policy to the VPC CNI service account
  attach_vpc_cni_policy = true
  vpc_cni_policy_name   = "AmazonEKSVPCCNIPolicy"
}

module "vpc_cni_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.33.0"

  create_role = true
  role_name   = "vpc-cni-role"

  provider_url = module.eks_cluster.cluster_oidc_issuer_url
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:aws-node"
  ]

  policy_arns = [
    aws_iam_policy.vpc_cni.arn
  ]
}

resource "aws_iam_policy" "vpc_cni" {
  name        = "AmazonEKSVPCCNIPolicy"
  description = "Policy for VPC CNI addon"
  policy      = file("vpc-cni-policy.json")
}

module "monitoring_stack" {
  source  = "terraform-aws-modules/eks/aws//modules/kubernetes-addons"
  version = "20.31.6"

  cluster_name = module.eks_cluster.cluster_name

  enable_prometheus = true
  enable_grafana    = true
  enable_alertmanager = true
}
