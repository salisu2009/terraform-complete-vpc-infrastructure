# This main.tf file cointains the actual recources we want to create in AWS account 2 describe -instance

# create kcvpc

resource "aws_vpc" "Kcvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "Kcvpc"
  }
}

#create publicsubnet

resource "aws_subnet" "Publicsubnet" {
  vpc_id    = aws_vpc.Kcvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "PublicSubnet"
  }
}

# create privateSubnet

resource "aws_subnet" "Privatesubnet" {
  vpc_id     = aws_vpc.Kcvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "PrivateSubnet"
  }
}

# create internet gateway

resource "aws_internet_gateway" "Kcigw" {
  vpc_id = aws_vpc.Kcvpc.id

  tags = {
    Name = "KC Internet Gateway"
  }
}

# configure Public Route table

resource "aws_route_table" "PublicRT" {
  vpc_id = aws_vpc.Kcvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Kcigw.id
  }

  
  tags = {
    Name = "PublicRT"
  }
}

# Associate the Public Route Table to the PublicSubnet

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.Publicsubnet.id
  route_table_id = aws_route_table.PublicRT.id
}

# configure Private Route table

resource "aws_route_table" "PrivateRT" {
  vpc_id = aws_vpc.Kcvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.Kcnatgw.id
  }

  
  tags = {
    Name = "PrivateRT"
  }
}

# Associate the Private Route Table to the PrivateSubnet

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.Privatesubnet.id
  route_table_id = aws_route_table.PrivateRT.id
}

# create elatic ip

resource "aws_eip" "Kceip" {
  #instance = aws_instance.web.id
  domain   = "vpc"
}

# create Nat Gateway

resource "aws_nat_gateway" "Kcnatgw" {
  allocation_id = aws_eip.Kceip.id
  subnet_id     = aws_subnet.Publicsubnet.id

  tags = {
    Name = "Kcnatgw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.Kcigw]
}

#create security group for public subnet
resource "aws_security_group" "public_sg" {
  name        = "PublicSecurityGroup"
  description = "Allow HTTP, HTTPS, and SSH"
  vpc_id      = aws_vpc.Kcvpc.id


  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

   tags = {
    Name = "PublicSecurityGroup"
   }
}
  

# create private security groups

resource "aws_security_group" "private_sg" {
  name        = "PrivateSecurityGroup"
  description = "Allow DB + SSH only from public subnet"
  vpc_id      = aws_vpc.Kcvpc.id

  ingress {
    description = "Postgres from Public subnet"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # CIDR of public subnet
  }

  ingress {
    description = "SSH from Public subnet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PrivateSecurityGroup"
  }
}

# create public nacl 
  resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.Kcvpc.id

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "PublictNACL"
  }
}

resource "aws_network_acl_association" "public_nacl_assoc" {
  subnet_id      = aws_subnet.Publicsubnet.id
  network_acl_id = aws_network_acl.public_nacl.id
}

# create private nacl

resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.Kcvpc.id

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "10.0.1.0/24" # public subnet
    from_port  = 5432
    to_port    = 5432
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "10.0.1.0/24"
    from_port  = 22
    to_port    = 22
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "PrivateNACL"
  }
}

resource "aws_network_acl_association" "private_nacl_assoc" {
  subnet_id      = aws_subnet.Privatesubnet.id
  network_acl_id = aws_network_acl.private_nacl.id
}


  # SSM Parameter Data Source
data "aws_ssm_parameter" "ubuntu_jammy" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# Create key pair from your existing public key
resource "aws_key_pair" "sayeed_key" {
  key_name   = "sayeed-key"
  public_key = file("~/.ssh/sayeed_key.pub")
}

# Create key pair for Muhammad using your existing public key
resource "aws_key_pair" "muhammad_key" {
  key_name   = "muhammad-key"
  public_key = file("~/.ssh/sayeed_key.pub")  # Using the same key as sayeed
}


# ------------------------
# EC2 Instances
# ------------------------
resource "aws_instance" "sayeed" {
  ami                         = data.aws_ssm_parameter.ubuntu_jammy.value
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.Publicsubnet.id
  key_name                    = aws_key_pair.sayeed_key.key_name
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y apache2
    systemctl enable apache2
    systemctl start apache2
    echo "<h1>Hello from sayeed (public)</h1>" > /var/www/html/index.html
  EOT

  tags = { Name = "sayeed" }
}

resource "aws_instance" "muhammad" {
  ami                    = data.aws_ssm_parameter.ubuntu_jammy.value
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Privatesubnet.id
  key_name               = aws_key_pair.muhammad_key.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = { Name = "muhammad" }
}

# Output private IP for SSH access (you'll need to connect through a bastion host)
output "muhammad_private_ip" {
  value = aws_instance.muhammad.private_ip
}