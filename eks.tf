module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "My-Cluster"
  kubernetes_version = "1.36"

  addons = {
    coredns = {
      before_compute = true
      # addon_version = "v1.14.3-eksbuild.3"
      resolve_conflicts_on_create = "OVERWRITE" // 
      most_recent                 = "true"
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = "true"
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
      most_recent    = "true"
    }
    # ebs-csi-driver = {
    #   before_compute = false
    #   most_recent    = "true"
    #   service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
    # }
  }

  # Optional
  endpoint_public_access = true

  # Optional: Adds the current caller identity (person who created tf code) as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  vpc_id = aws_vpc.my_vpc.id
  subnet_ids = [
    aws_subnet.private_1a.id,
    aws_subnet.private_1b.id
  ]

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    node_group = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t2.small"] // CPU: 1   Mem: 2 GiB RAM

      min_size     = 4 //total amount of running worker nodes spread across the subnets. 
      max_size     = 5
      desired_size = 4
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_eks_access_entry" "dev_sso_user" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/${var.sso_role}"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "dev_sso_user_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.dev_sso_user.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn  
  depends_on = [aws_iam_role.ebs_csi_driver, module.eks] 
}