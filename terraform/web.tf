provider "aws" {
  region = "${var.region}"
}

module "vpc" {
  source        = "github.com/terraform-community-modules/tf_aws_vpc"
  name = "my-vpc"
  cidr = "10.0.0.0/16"
  #private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway = "true"

  azs      = ["eu-west-1a", "eu-west-1b"]

}

resource "aws_instance" "web" {
  ami                         = "${lookup(var.ami, var.region)}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${aws_key_pair.ssh_public_key.key_name}"
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  private_ip                  = "${var.instance_ips[count.index]}"
  user_data                   = "${file("files/web_bootstrap.sh")}"
  associate_public_ip_address = true

  vpc_security_group_ids = [
    "${aws_security_group.web_host_sg.id}"
  ]

  tags {
    Name = "dummyapp-${format("%03d", count.index + 1)}"
  }

  iam_instance_profile = "${aws_iam_instance_profile.web_instance_profile.id}"
  count = "${length(var.instance_ips)}"
}

resource "aws_alb_target_group" "alb_target_group_web" {
  name                 = "web"
  port                 = "80"
  protocol             = "HTTP"
  vpc_id               = "${module.vpc.vpc_id}"
  deregistration_delay = 30

  health_check {
    path                = "/"
    port                = "80"
    healthy_threshold   = "2"
    unhealthy_threshold = "3"
    interval            = "90"
    matcher             = "200"
  }
}

resource "aws_alb" "webalb" {
  name            = "webalb"
  subnets         = ["${module.vpc.public_subnets}"]
  security_groups = ["${aws_security_group.web_inbound_sg.id}"]

  idle_timeout    = 3600

  enable_deletion_protection = false
}

resource "aws_alb_listener" "web" {
  load_balancer_arn = "${aws_alb.webalb.arn}"
  port              = "80"
  protocol          = "HTTP"
  #ssl_policy        = "ELBSecurityPolicy-2015-05"
  #certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_web.arn}"
    type             = "forward"
  }
}

#resource "aws_instance" "web_production" {
#  ami                         = "${lookup(var.ami, var.region)}"
#  instance_type               = "${var.instance_type}"
#  key_name                    = "${aws_key_pair.ssh_public_key.key_name}"
#  subnet_id                   = "${module.vpc.public_subnets[0]}"
#  private_ip                  = "${var.prod_instance_ips[count.index]}"
#  user_data                   = "${file("files/web_bootstrap.sh")}"
#  associate_public_ip_address = true
#
#  vpc_security_group_ids = [
#    "${aws_security_group.web_host_sg.id}",
#  ]
#
#  tags {
#    Name = "dummyapp_prod-${format("%03d", count.index + 1)}"
#  }
#
#  iam_instance_profile = "${aws_iam_instance_profile.web_instance_profile.id}"
#  count = "${length(var.prod_instance_ips)}"
#}

#resource "aws_instance" "deployment" {
#  ami                         = "${lookup(var.ami, var.region)}"
#  instance_type               = "${var.instance_type}"
#  key_name                    = "${aws_key_pair.ssh_public_key.key_name}"
#  subnet_id                   = "${module.vpc.public_subnet_id}"
#  user_data                   = "${file("files/web_bootstrap.sh")}"
#  associate_public_ip_address = true
#
#  provisioner "file" {
#    source = "id_rsa"
#    destination = "/home/ubuntu/.ssh/id_rsa"
#    connection {
#      private_key = "${file("id_rsa")}"
#      user = "ubuntu"
#      agent = false
#    }
#  }
#
#  provisioner "remote-exec" {
#    inline = "sudo chmod 400 /home/ubuntu/.ssh/id_rsa"
#    connection {
#      private_key = "${file("id_rsa")}"
#      user = "ubuntu"
#      agent = false
#    }
#  }
#
#  vpc_security_group_ids = ["${aws_security_group.web_host_sg.id}"]
#
#  tags {
#    Name = "deployment"
#  }
#
#  iam_instance_profile = "${aws_iam_instance_profile.web_instance_profile.id}"
#}

# Create an IAM role for the Web Servers.
resource "aws_iam_role" "web_iam_role" {
    name = "web_iam_role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "web_instance_profile" {
    name = "web_instance_profile"
    roles = ["web_iam_role"]
}

resource "aws_iam_role_policy" "web_iam_role_policy" {
  name = "web_iam_role_policy"
  role = "${aws_iam_role.web_iam_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "autoscaling:Describe*",
      "Resource": "*"
    },
    {
      "Action": [
        "rds:*",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:GetMetricStatistics",
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "sns:ListSubscriptions",
        "sns:ListTopics",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": "elasticache:*",
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "elasticsearch" {
  name = "elasticsearch"
  role = "${aws_iam_role.web_iam_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "elasticache:*",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_key_pair" "ssh_public_key" {
  key_name = "ssh public key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDXVf53RXsc2fM2elVt37H+bIUjRMUG7ii8zQgblsCqquuMP29OnTFux/lLuMuFwn5UC3b+7wYBHUzzGhvvw+jtwRjCFt+jiOiVTmZQpwyAEPRt7OWuGPyyX+K8tXARBcsmFaFDqrlntZ0UPglxfPw7PtTNFCkhAZ9PAzq0OD4wtIgcXejKRO3ybNyKy8I4yHz2VH5BytLEHHA9QoHssBOhOChyvIdp5vTBNdL78cD9hKsFRRn1m1/VKlvVwPdgDw/RMBdQmblc/mevwRrqOb6QpgCcWfo00xeYF9wMJmt6ItdMMfwWJ7epXeVRuFwFpmVWkRVWSw+7Ag2ujHEftUld7hVXoHVaJLLWQsiHbrhuoQuVw50mBI80Tpep2Jj0jXq97JK6pKYk8kkv+FtVbALePDK+MjY5pgE5p9PmhElfAAvz3juZsHTKKGRCfdFnvTs9/NbARZ0p17kuOVG9JVNvtRG3px8AY8watzvXAWMBLVCi0x/SFixcHHCDXUv+cAr+86n3Dwk0dLktMyAdpFPPJvbO9QBN87fLEQJGoxelaO92AdiiYKKfQVCoS/CD7Dr/P/OPb4Gt7lbnpR6h6HM/Atwn1BwHUPipj/aRJZ5wu6zsNY1a51WTyxhdXlsi7QiA/3sX2Ar9s3iChWyX27qbkhDhPOPgna2wKaoiOOQcGw== co.ranieri@gmail.com"
}

resource "aws_elb" "web" {
  name = "web-elb"

  subnets         = ["${module.vpc.public_subnets[0]}"]
  security_groups = ["${aws_security_group.web_inbound_sg.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  # The instances are registered automatically
  instances = ["${aws_instance.web.*.id}"]
}

#resource "aws_elb" "web_prod" {
#  name = "web-elb-prod"
#
#  subnets         = ["${module.vpc.public_subnets[0]}"]
#  security_groups = ["${aws_security_group.web_inbound_sg.id}"]
#
#  listener {
#    instance_port     = 80
#    instance_protocol = "http"
#    lb_port           = 80
#    lb_protocol       = "http"
#  }
#
#  # The instances are registered automatically
#  instances = ["${aws_instance.web_production.*.id}"]
#}

resource "aws_security_group" "web_inbound_sg" {
  name        = "web_inbound"
  description = "Allow HTTP from Anywhere"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_host_sg" {
  name        = "web_host"
  description = "Allow SSH & HTTP to web hosts"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0", "10.0.0.0/16"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "userdata_appweb" {
  template = "${file("userdata")}"
  vars     = {}
}


// Launch Configuration
resource "aws_launch_configuration" "lc" {
  lifecycle {
    create_before_destroy = true
  }

  security_groups = ["${aws_security_group.web_inbound_sg.id}"]

  image_id                    = "${lookup(var.ami, var.region)}"
  instance_type               = "t1.micro"
  #iam_instance_profile        = "${var.iam_instance_profile}"
  #key_name                    = "dummy-app"
  user_data                    = "${data.template_file.userdata_appweb.rendered}"
  #associate_public_ip_address = "${var.assign_public_ip}"
  #enable_monitoring           = "${var.envtype == "nonprod" ? false : true}"
  #ebs_optimized               = "${var.ebs_optimized}"
}

// Auto-Scaling Group Configuration
resource "aws_autoscaling_group" "asg-2" {
  lifecycle {
    create_before_destroy = true
  }

  name                = "web-${aws_launch_configuration.lc.name}"
  availability_zones  = ["eu-west-1a", "eu-west-1b"]
  vpc_zone_identifier = ["${module.vpc.public_subnets}"]

  // Use the Name from the launch config created above
  launch_configuration      = "${aws_launch_configuration.lc.name}"
  min_size                  = "1"
  max_size                  = "2"
  min_elb_capacity          = "1"
  #health_check_grace_period = "${var.health_check_grace_period}"
  #health_check_type         = "${var.health_check_type}"

  #load_balancers = ["${compact(var.additional_elb)}"]

  #enabled_metrics = ["${var.enabled_metrics}"]

  #target_group_arns = ["${concat(aws_alb_target_group.alb_target_group.id,var.additional_targetgroups)}"]
  target_group_arns = ["${aws_alb_target_group.alb_target_group_web.id}"]
}
