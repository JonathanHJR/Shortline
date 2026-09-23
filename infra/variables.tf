variable "aws_region" {
  default = "ap-southeast-1"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "app_port" {
  default = 8080
}

variable "ecr_image" {
  default = "910929919817.dkr.ecr.ap-southeast-1.amazonaws.com/shortline:latest"
}
