terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
}

#Create key-pair for logging into EC2 in us-east-1
resource "aws_key_pair" "webserver-key" {
  key_name   = "webserver-key"
  public_key = file("~/.ssh/aws_key.pub")
}

#Get Linux AMI ID using SSM Parameter endpoint in us-east-1
data "aws_ssm_parameter" "webserver-ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#Create VPC in us-east-1
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "terraform-vpc"
  }
}

#Create IGW in us-east-1
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

#Get main route table to modify
data "aws_route_table" "main_route_table" {
  filter {
    name   = "association.main"
    values = ["true"]
  }
  filter {
    name   = "vpc-id"
    values = [aws_vpc.vpc.id]
  }
}
#Create route table in us-east-1
resource "aws_default_route_table" "internet_route" {
  default_route_table_id = data.aws_route_table.main_route_table.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Terraform-RouteTable"
  }
}

#Get all available AZ's in VPC for master region
data "aws_availability_zones" "azs" {
  state = "available"
}

#Create subnet # 1 in us-east-1
resource "aws_subnet" "subnet" {
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
}


#Create SG for allowing TCP/80 & TCP/22
resource "aws_security_group" "sg" {
  name        = "sg"
  description = "Allow TCP/80 & TCP/22"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow traffic from TCP/80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow traffic from TCP/80"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow traffic from TCP/5432"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow traffic from TCP/4200"
    from_port   = 4200
    to_port     = 4200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow traffic from TCP/4200"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "kanban-Public-IP" {
  value = aws_instance.kanbanexample.public_ip
}

output "books-Public-IP" {
  value = aws_instance.books.public_ip
}

resource "aws_instance" "books" {
  ami           = "ami-027c83104e9745fdf"
  instance_type = "t2.micro"
  key_name                    = aws_key_pair.webserver-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg.id]
  subnet_id                   = aws_subnet.subnet.id

  provisioner "remote-exec" {
    inline = [
      "sudo git clone https://github.com/yomarajazmin/terraform_example.git",
      "cd terraform_example",
      "cd books",
      "sudo docker-compose up -d"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/aws_key.pem")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "BooksServerInstance"
  }
}



resource "aws_instance" "kanbanexample" {
  ami           = "ami-027c83104e9745fdf"
  instance_type = "t2.micro"
  key_name                    = aws_key_pair.webserver-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg.id]
  subnet_id                   = aws_subnet.subnet.id

  provisioner "remote-exec" {

    inline = [
      "sudo git clone https://github.com/yomarajazmin/terraform_example.git",
      "cd terraform_example",
      "cd app",
      "sudo docker-compose up -d"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/aws_key.pem")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "KanbanServerInstance"
  }
}