variable "package_bucket" {
  type = string
  description = "Name of the S3 bucket where pypi packages are to be stored"
}

variable "region" {
  type = string
}

variable "log_group" {
  type = string
  description = "CloudWatch log group for access logs"
}
