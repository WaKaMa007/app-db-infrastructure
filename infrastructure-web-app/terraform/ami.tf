# AMI module for the app_db module

# Ubuntu AMI

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical

  #  owners = ["137112412989"] # Amazon  # This is the owner when using Amazon EC2 instance. 

}

# Amazon Linux AMI

#data "aws_ami" "amazon_linux" {
#  most_recent = true

#  filter {
#    name   = "name"
#    values = ["amzn2-ami-hvm-2.0.*-x86_64-ebs"]
#  }

#  owners = ["137112412989"] # Amazon

#}