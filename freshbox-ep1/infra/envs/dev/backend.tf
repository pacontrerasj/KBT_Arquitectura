terraform {
  backend "s3" {
    bucket         = "freshbox-s3-tfstate"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "freshbox-terraform-locks"
    encrypt        = true
  }
}
