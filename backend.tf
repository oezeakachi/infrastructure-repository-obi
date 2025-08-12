terraform {
  backend "s3" {
    bucket = "mir-obi-bucket"
    key    = "key/terraform.tfstate"
    region = "eu-west-1"
  }
}