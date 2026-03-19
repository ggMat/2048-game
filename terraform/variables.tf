variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "tags" {
  type = map(string)
  default = {
    Project = "2048-game"
    Env     = "production"
    }
}
