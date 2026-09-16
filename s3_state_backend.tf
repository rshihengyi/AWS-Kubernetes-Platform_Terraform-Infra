terraform {
  backend "s3" {
    //profile      = "DevUser"
    bucket       = "enterprise-kubernetes-platform-tf-state"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}