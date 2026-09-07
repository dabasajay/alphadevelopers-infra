terraform {
  backend "s3" {
    bucket       = "alphadevelopers-tfstate"
    key          = "prod/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
