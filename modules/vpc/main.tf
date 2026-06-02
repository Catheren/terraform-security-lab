resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name               = var.vpc_name
    Environment        = var.environment
    Owner              = "security-team"
    Project            = "security-lab"
    DataClassification = "internal"
  }
}
resource "aws_subnet" "this" {
  vpc_id     = aws_vpc.this.id
  cidr_block = var.subnet_cidr
  # Instances do not get public IPs by default.
  # Assign explicitly only where internet access is required.
  map_public_ip_on_launch = false

  tags = {
    Name               = "${var.vpc_name}-subnet"
    Environment        = var.environment
    Owner              = "security-team"
    Project            = "security-lab"
    DataClassification = "internal"
  }
}
# Lock down the default security group — no inbound or outbound traffic.
# Forces all resources to use explicitly defined security groups.
# This prevents accidental exposure from resources using the default SG.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  tags = {
    Environment        = var.environment
    Owner              = "security-team"
    Project            = "security-lab"
    DataClassification = "internal"
  }

  # no ingress or egress rules = deny all traffic
}