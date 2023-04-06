provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_subnet" "private1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "ec2" {
  name_prefix = "ec2-sg-"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "elb" {
  name_prefix = "elb-sg-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2-1" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name      = "MyKeyPair"

  tags = {
    Name = "EC2-1"
  }
}

resource "aws_instance" "ec2-2" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public2.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name      = "MyKeyPair"

  tags = {
    Name = "EC2-2"
  }
}

resource "aws_eip" "nat" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat
  subnet_id = aws_subnet.public1.id
}

resource "aws_route" "nat" {
    route_table_id = aws_route_table.private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
}

resource "aws_elb" "elb" {
    name = "my-elb"
    subnets = [aws_subnet.public1.id, aws_subnet.public2.id]
    security_groups = [aws_security_group.elb.id]
        listener {
        instance_port = 80
        instance_protocol = "http"
        lb_port = 80
        lb_protocol = "http"
    }
}

resource "aws_autoscaling_group" "ec2" {
    name = "ec2-asg"
    max_size = 2
    min_size = 2
    desired_capacity = 2
    launch_configuration = aws_launch_configuration.ec2.id
    vpc_zone_identifier = [aws_subnet.private1.id, aws_subnet.private2.id]
}

resource "aws_launch_configuration" "ec2" {
    name_prefix = "ec2-lc-"
    image_id = "ami-0c94855ba95c71c99"
    instance_type = "t2.micro"
    key_name = "MyKeyPair"

    security_groups = [aws_security_group.ec2.id]

        user_data = <<-EOF
        #!/bin/bash
        echo "Hello World" > /var/www/html/index.html
        yum update -y
        yum install -y httpd
        systemctl start httpd.service
        systemctl enable httpd.service
        EOF
    }

output "elb_dns_name" {
    value = aws_elb.elb.dns_name
}
