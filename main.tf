terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile    = "default"
  region     = "us-west-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "bastion_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bastion_vpc"
  }
}

resource "aws_eip" "eib" {
  vpc = true
}

resource "aws_internet_gateway" "bastion_igw" {
  vpc_id = aws_vpc.bastion_vpc.id

  tags = {
    Name = "bastion_IGW"
  }
}

resource "aws_nat_gateway" "bastion_nat" {
  allocation_id = aws_eip.eib.id
  subnet_id     = aws_subnet.bastion_public.id

  tags = {
    Name = "bastion_NAT"
  }
  # maintaining proper order
  depends_on = [aws_internet_gateway.bastion_igw]
}

resource "aws_subnet" "bastion_public" {
  vpc_id                  = aws_vpc.bastion_vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "bastion_public"
  }
}

resource "aws_subnet" "bastion_private" {
  vpc_id     = aws_vpc.bastion_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "bastion_private"
  }
}

resource "aws_route_table" "bastion_public_rt" {
  vpc_id = aws_vpc.bastion_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bastion_igw.id
  }

  tags = {
    Name = "bastion_public_rt"
  }
}

resource "aws_route_table" "bastion_private_rt" {
  vpc_id = aws_vpc.bastion_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.bastion_nat.id
  }

  tags = {
    Name = "private_rt"
  }
}

#resource "aws_lb" "bastion_nlb" {
#  name               = "bastion-lb"
#  internal           = true
#  load_balancer_type = "network"
#  subnets            = aws_subnet.bastion_public.id
  
#  enable_deletion_protection = true
  
#  tags = {
#    Name = "bastion_nlb"
#  }
#}

resource "aws_instance" "bastion" {
  ami                         = "ami-969ab1f6"
  key_name                    = var.key_name
  instance_type               = "t2.micro"
  security_groups             = ["${aws_security_group.bastion-sg.name}"]
  associate_public_ip_address = true
}

resource "aws_security_group" "bastion-sg" {
  name   = "bastion-security-group"
  vpc_id = aws_vpc.bastion_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [aws_vpc.bastion_vpc.cidr_block]
  }

  egress {
    protocol    = -1
    from_port   = 0 
    to_port     = 0 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route_table_association" "bastion_public_rta" {
  subnet_id      = aws_subnet.bastion_public.id
  route_table_id = aws_route_table.bastion_public_rt.id
}

resource "aws_route_table_association" "bastion_private_rta" {
  subnet_id      = aws_subnet.bastion_private.id
  route_table_id = aws_route_table.bastion_private_rt.id

}

output "bastion_public_ip" {
  value = "${aws_instance.bastion.public_ip}"
}
