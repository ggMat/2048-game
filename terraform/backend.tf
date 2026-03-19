terraform {
  backend "s3" {
    bucket = "my-remote-terraform-states-405989524795"
    key    = "portfolio/2048-game/terraform.tfstate"
    region = "eu-central-1"
    //dynamodb_table = "terraform-locks" #Uncomment for production deployments to ensure only one user can make changes at a time
    encrypt = true
  }
}
