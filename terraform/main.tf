terraform {
  backend "s3" {
    bucket = "serokell-stakerdao-tfstate"
    dynamodb_table = "serokell-stakerdao-tfstate-lock"
    encrypt = true
    key    = "agora/terraform.tfstate"
    region = "eu-west-2"
    profile = "stakerdao"
  }
}

provider  "aws" {
  version = "~> 3.20"
  region = "eu-west-2"
  profile = "stakerdao"
}

# Grab the latest NixOS AMI built by Serokell
data "aws_ami" "nixos" {
  most_recent = true

  filter {
    name = "name"
    values = ["NixOS-*"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["920152662742"] # Serokell
}

## Blend demo
resource "aws_instance" "blend_demo" {
  key_name = aws_key_pair.balsoft.key_name

  # Networking
  subnet_id = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  ipv6_address_count = 1
  vpc_security_group_ids = [
    aws_security_group.egress_all.id,
    aws_security_group.http.id,
    aws_security_group.ssh.id,
    aws_security_group.wireguard.id,
  ]

  # Instance parameters
  instance_type = "t3a.nano"
  monitoring = true

  # Disk type, size, and contents
  ami = data.aws_ami.nixos.id

  lifecycle {
    ignore_changes = [ ami, user_data ]
  }

  ebs_optimized = true
  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
  }
}

## Blend demo
resource "aws_instance" "bridge_testing" {
  key_name = aws_key_pair.balsoft.key_name

  # Networking
  subnet_id = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  ipv6_address_count = 1
  vpc_security_group_ids = [
    aws_security_group.egress_all.id,
    aws_security_group.http.id,
    aws_security_group.ssh.id,
    aws_security_group.wireguard.id,
  ]

  # Instance parameters
  instance_type = "t3a.nano"
  monitoring = true

  # Disk type, size, and contents
  ami = data.aws_ami.nixos.id

  lifecycle {
    ignore_changes = [ ami, user_data ]
  }

  ebs_optimized = true
  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
  }
}


# Allow ALL egress traffic
resource "aws_security_group" "egress_all" {
  name = "egress_all"
  description = "Allow inbound and outbound traffic on 9732 and 8732"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Allow SSH traffic
resource "aws_security_group" "ssh" {
  name = "ssh"
  description = "Allow inbound and outbound traffic on 9732 and 8732"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port = 17788
    to_port = 17788
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Allow Frontend traffic
resource "aws_security_group" "http" {
  name = "http"
  description = "Allow inbound and outbound traffic for the Agora frontend"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Allow wireguard traffic
resource "aws_security_group" "wireguard" {
  name = "wireguard"
  description = "Allow inbound and outbound traffic for wireguard"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port        = 51820
    to_port          = 51820
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Network resources
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  version = "= v2.69"

  name = "tezos-cluster-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  public_subnets   = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  public_subnet_ipv6_prefixes     = [0, 1, 2]

  enable_ipv6                     = true
  assign_ipv6_address_on_creation = true

  enable_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support = true

  enable_dhcp_options              = true
  dhcp_options_domain_name         = "tezos.serokell.team"
  dhcp_options_domain_name_servers = ["10.0.0.2"]

  tags = {
    Terraform = "true"
    Environment = "production"
  }
}

## Extra resources
resource "aws_key_pair" "mkaito" {
  key_name   = "mkaito"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDOySJ7SAmh+3CBK4fagwkY9PsF6xF+9msMRoQN6JalpauQANALVsVDjC3heFH6Lc/tjLrhQ46oVO3xMFGVKxNe81gaWhvWPxytfH5V8FP52GWEo5HwwMd+VoEyJIYYbj10jwkuzutr9fF0qlp0nhR1IaTKnxJFxV8tUkpiC3a9Qf4yrNy7Ft6DMwyiZSh/mEx+S4LuMqayb93do7+ddlSAyb70NQrLv7H2IRA+qkAzPhZe80o3FqKRvXayH5GSSuYLFfEPFgy0guKAA7P2ICjddLJ+l8BAdTlF8ADY1Z97DvCAgG6CT4cnRzv+cSM+Uvd+ZTxBY6Z+U27kO2LB7UBhVLzrWHSRbv5KWaruFzhOD3E64y3+7XzUg0DpoeS2QVahYc3iF4FvpVfLLPX3F4aev/83Z05G6nEn8lDb1XPAV0KRwo0gB4cCknC6MurnIzxgAeElin9DL5KgVMgVr5jIgBhx01Z9VEVNs5UcMDrA2mXHenY0uAnNk+iWeKZdzxxet50gQuebJ5Q3jHCADS6WZZsBdjxTDiLNvBVo1OiaZ4/tubzVZdrmCkPZDyPUO04Gz7rqXdVFiqzCJgVbcv2gX1qe8UthlRmdblX+l2fY4gvAOGNchVG1cMmvuA5i27td0PqDh6I7kQPvqKQ3QkCI012hwW9ca5S3HGtQDgqSZQ== cardno:000607309598"
}

resource "aws_key_pair" "balsoft" {
  key_name = "balsoft"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDd2OdcSHUsgezuV+cpFqk9+Svtup6PxIolv1zokVZdqvS8qxLsA/rwYmQgTnuq4/zK/GIxcUCH4OxYlW6Or4M4G7qrDKcLAUrRPWkectqEooWRflZXkfHduMJhzeOAsBdMfYZQ9024GwKr/4yriw2BGa8GbbAnQxiSeTipzvXHoXuRME+/2GsMFAfHFvxzXRG7dNOiLtLaXEjUPUTcw/fffKy55kHtWxMkEvvcdyR53/24fmO3kLVpEuoI+Mp1XFtX3DvRM9ulgfwZUn8/CLhwSLwWX4Xf9iuzVi5vJOJtMOktQj/MwGk4tY/NPe+sIk+nAUKSdVf0y9k9JrJT98S/ cardno:000610645773"
}

## DNS
resource "aws_route53_zone" "stakerdao_serokell_team" {
  name = "stakerdao.serokell.team"
}

### FIXME: Fix DNS records below when switching to new servers

## Blend Demo
resource "aws_route53_record" "blend_demo_ipv4" {
  zone_id = aws_route53_zone.stakerdao_serokell_team.zone_id
  name    = "blend.stakerdao.serokell.team"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.blend_demo.public_ip]
}

resource "aws_route53_record" "blend_demo_ipv6" {
  zone_id = aws_route53_zone.stakerdao_serokell_team.zone_id
  name    = "blend.stakerdao.serokell.team"
  type    = "AAAA"
  ttl     = "60"
  records = [aws_instance.blend_demo.ipv6_addresses[0]]
}

## Bridge Testing
resource "aws_route53_record" "bridge_testing_ipv4" {
  zone_id = aws_route53_zone.stakerdao_serokell_team.zone_id
  name    = "bridge.stakerdao.serokell.team"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.bridge_testing.public_ip]
}

resource "aws_route53_record" "bridge_testing_ipv6" {
  zone_id = aws_route53_zone.stakerdao_serokell_team.zone_id
  name    = "bridge.stakerdao.serokell.team"
  type    = "AAAA"
  ttl     = "60"
  records = [aws_instance.bridge_testing.ipv6_addresses[0]]
}

## Bucket for TF state storage
resource "aws_s3_bucket" "tfstate" {
  bucket = "serokell-stakerdao-tfstate"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

## DynamoDB for TF locking and state
resource "aws_dynamodb_table" "tfstatelock" {
  name = "serokell-stakerdao-tfstate-lock"
  hash_key = "LockID"
  read_capacity = 20
  write_capacity = 20

  lifecycle {
    prevent_destroy = true
  }

  attribute {
    name = "LockID"
    type = "S"
  }
}

## Outputs for scripting
output "stakerdao_ns" {value = [ aws_route53_zone.stakerdao_serokell_team.name_servers ]}

output "blend_demo_id" {value = aws_instance.blend_demo.id}
output "blend_demo_az" {value = aws_instance.blend_demo.availability_zone}
output "blend_demo_ipv4" {value = aws_instance.blend_demo.public_ip}
output "blend_demo_ipv6" {value = aws_instance.blend_demo.ipv6_addresses[0]}
