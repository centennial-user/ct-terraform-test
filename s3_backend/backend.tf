terraform {
  backend "s3" {
    bucket         = "centennial-tf-state"
    key            = "ct-terraform-test/S3/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "ct-tf-locks"
  }
}