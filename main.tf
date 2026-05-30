module "s3_logs" {
  source = "./modules/s3"

  bucket_name = var.bucket_name
  environment = var.environment
}


module "logging" {
  source = "./modules/logging"

  bucket_name = var.trail_bucket_name
}

module "iam" {
  source    = "./modules/iam"
  role_name = "ec2-security-role-dev"
}

module "vpc" {
  source = "./modules/vpc"

  vpc_name    = "security-lab-vpc"
  vpc_cidr    = "10.0.0.0/16"
  subnet_cidr = "10.0.1.0/24"
}

module "ec2" {
  source = "./modules/ec2"

  ami_id        = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  instance_name = "security-lab-instance"

  subnet_id = module.vpc.subnet_id

  instance_profile_name = module.iam.instance_profile_name

  environment = var.environment
}