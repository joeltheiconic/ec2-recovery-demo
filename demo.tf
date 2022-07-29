provider "aws" {
  region  = "ap-southeast-2"
}

#####
#####     Get my public IP address
#####

resource "null_resource" "get_my_ip" {
  triggers = {
    build_number = timestamp()
  }

  provisioner "local-exec" {
    command = "curl -s http://icanhazip.com | tr -d \"\\n\" > myip.txt"
  }
}

#####
#####     Network setup
#####

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "joels-demo-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["ap-southeast-2a"]
  public_subnets = ["10.0.0.0/16"]
}


resource "aws_security_group" "this" {
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${file("myip.txt")}/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["${file("myip.txt")}/32"]
  }
}

#####
#####     Broken instances - note that there's no key being specified so we won't have access
#####

resource "aws_instance" "broken_linux" {
  ami           = "ami-0e040c48614ad1327"
  instance_type = "t2.nano"
  subnet_id     = module.vpc.public_subnets[0]
  security_groups = [aws_security_group.this.id]
  user_data     = <<EOF
	  #! /bin/bash
    apt update
    apt install -y apache2
    systemctl start apache2
    systemctl enable apache2
    echo "<h1>Deployed via Terraform</h1>" > /var/www/html/index.html
	EOF

  tags = {
    "Name" = "broken-linux"
  }
}

resource "aws_instance" "broken_windows" {
  ami           = "ami-0b8bde09553e44376"   # Windows 2012 R2
  instance_type = "m4.xlarge"
  subnet_id     = module.vpc.public_subnets[0]
  security_groups = [aws_security_group.this.id]

  tags = {
    "Name" = "broken-windows"
  }
}

#####
#####     Recovery instances
#####

resource "aws_instance" "recovery_linux" {
  ami           = "ami-0e040c48614ad1327"
  instance_type = "t2.nano"
  subnet_id     = module.vpc.public_subnets[0]
  security_groups = [aws_security_group.this.id]
  key_name = "joel-test"
  user_data     = <<EOF
	#! /bin/bash
    apt update
    apt install -y apache2
    systemctl start apache2
    systemctl enable apache2
    echo "<h1>Deployed via Terraform</h1>" > /var/www/html/index.html
	EOF

  tags = {
    "Name" = "recovery-linux"
  }
}

resource "aws_instance" "recovery_windows" {
  ami           = "ami-0177a8353c3b60b90" # latest Windows version?
  instance_type = "m4.xlarge"
  subnet_id     = module.vpc.public_subnets[0]
  security_groups = [aws_security_group.this.id]
  key_name = "joel-test"

  tags = {
    "Name" = "recovery-windows"
  }
}

output "recovery_windows_password_hint" {
  value = "aws ec2 get-password-data --instance-id ${aws_instance.recovery_windows.id} --priv-launch-key ~/.ssh/${aws_instance.recovery_windows.key_name}.pem --region ap-southeast-2"
}
