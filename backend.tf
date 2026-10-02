terraform {
  backend "s3" {
    bucket = "sheriff-tf-backend"
    key    = "sadia/terraform.tfstate"
    region = "us-east-1"
  }
}