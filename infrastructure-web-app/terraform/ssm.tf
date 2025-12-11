# The session manager is used to connect to the EC2 instances using the AWS CLI.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm_role" {
  name               = "${local.name_prefix}-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${local.name_prefix}-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

#for ssm to work, make sure you have aws cli configured and also ssm plugin installed



#install session manager plugin
#curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
#sudo dpkg -i session-manager-plugin.deb
#sudo rm -rf session-manager-plugin.deb
#aws ssm start-session --target <instance-id>