/*
    ArgoCD Helm Chart v9.5.9
*/

# resource "kubernetes_namespace_v1" "argocd" {
#   metadata {
#     name = "argocd"
#   }
#   depends_on = [module.eks, aws_eks_access_entry.dev_sso_user]
# }

resource "kubernetes_storage_class_v1" "grafana_storage_class" {
  metadata {
    name = "gp3"
  }

  storage_provisioner = "ebs.csi.aws.com"
  parameters = {
    type              = "gp3"
    volume_binding_mode  = "WaitForFirstConsumer"
  }
  depends_on = [module.eks, aws_eks_access_entry.dev_sso_user]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "9.5.9"
  namespace  = "argocd"
  depends_on = [module.eks, aws_eks_access_entry.dev_sso_user]
}

# /*
#     Ingress Controller (AWS load balancer controller) Helm Chart
# */

resource "helm_release" "ingress_controller" {
  name       = "aws-lb-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.5.0"
  namespace  = "kube-system"
  depends_on = [module.eks, aws_eks_access_entry.dev_sso_user]

  /* need to specify:
    - clusterName
    - region
    - vpcId
    - serviceAccount.create
    - serviceAcount.name
*/

  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "region"
      value = var.my_region
    },
    {
      name  = "vpcId"
      value = aws_vpc.my_vpc.id
    },
    {
      name  = "serviceAccount.create" // 
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    }
  ]
}

/*
    ExternalDNS Helm Chart
*/

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.21.1"
  namespace  = "kube-system"
  depends_on = [module.eks, aws_eks_access_entry.dev_sso_user]

  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "region"
      value = var.my_region
    },
    {
      name  = "vpcId"
      value = aws_vpc.my_vpc.id
    },
    {
      name  = "serviceAccount.create"
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = "external-dns"
    }
  ]
}