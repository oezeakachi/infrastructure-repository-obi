terraform {
  backend "s3" {
    bucket = "mir-obi-bucket-v2"
    key    = "key/terraform.tfstate"
    region = "eu-west-1"
  }
}