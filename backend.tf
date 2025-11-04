terraform {
  backend "s3" {
    bucket = "mir-obi-bucket-v1"
    key    = "key/terraform.tfstate"
    region = "eu-west-1"
  }
}