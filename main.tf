provider "aws" {
  region = var.my_region
  # profile = "DevUser"
}

// Source: https://developer.hashicorp.com/terraform/tutorials/kubernetes/helm-provider?in=terraform%2Fkubernetes
provider "helm" {
  kubernetes = {
    //  config_path            = "~/.kube/config"
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    /*
    Shells out to AWS CLI using credentials the CLI resolves at that momement
    These credentials may not be the same role that applies the cluster

    Generate short-lived authentication to access the cluster with kubectl
*/


    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--profile", "DevUser"]
  }
}



