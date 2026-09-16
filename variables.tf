variable "my_region" {
  description = "Region where the resource(s) will be managed"
  type        = string
}

variable "region_a" {
  type = string
}

variable "region_b" {
  type = string
}

variable "db_password" {
  type = string
}

variable "sso_role" {
  type = string
}

variable "github_owner_id" {
  type = string
}

variable "github_repo_id" {
  type = string
}
