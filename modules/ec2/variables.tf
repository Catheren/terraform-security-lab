variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "instance_name" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "subnet_id" {
  type = string
}