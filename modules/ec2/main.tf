resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id = var.subnet_id

  iam_instance_profile = var.instance_profile_name

  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}