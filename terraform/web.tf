provider "aws" {
  region = "${var.region}"
}

module "vpc" {
  source        = "github.com/turnbullpublishing/tf_vpc.git?ref=v0.0.1"
  name          = "web"
  cidr          = "10.0.0.0/16"
  public_subnet = "10.0.1.0/24"
}

resource "aws_instance" "web" {
  ami                         = "${lookup(var.ami, var.region)}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${aws_key_pair.ssh_public_key.key_name}"
  subnet_id                   = "${module.vpc.public_subnet_id}"
  private_ip                  = "${var.instance_ips[count.index]}"
  user_data                   = "${file("files/web_bootstrap.sh")}"
  associate_public_ip_address = true

  vpc_security_group_ids = [
    "${aws_security_group.web_host_sg.id}",
  ]

  tags {
    Name = "dummyapp-${format("%03d", count.index + 1)}"
  }

  count = "${length(var.instance_ips)}"
}

resource "aws_instance" "deployment" {
  ami                         = "${lookup(var.ami, var.region)}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${aws_key_pair.ssh_public_key.key_name}"
  subnet_id                   = "${module.vpc.public_subnet_id}"
  user_data                   = "${file("files/web_bootstrap.sh")}"
  associate_public_ip_address = true

  provisioner "file" {
    source = "id_rsa"
    destination = "/home/ubuntu/.ssh/id_rsa"
    connection {
      private_key = "${file("id_rsa")}"
      user = "ubuntu"
      agent = false
    }
  }

  provisioner "remote-exec" {
    inline = "sudo chmod 400 /home/ubuntu/.ssh/id_rsa"
    connection {
      private_key = "${file("id_rsa")}"
      user = "ubuntu"
      agent = false
    }
  }

  vpc_security_group_ids = ["${aws_security_group.web_host_sg.id}"]

  tags {
    Name = "deployment"
  }
}

resource "aws_key_pair" "ssh_public_key" {
  key_name = "ssh public key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCneYF5svEkijvD0thTEqoBQdch+ondj4+LcWNWEljUKBHavWvV+YouyNvSh+DHmfpg6GnDW/LsF5wBg5joIBx0qH5QdLep6GKXhaVDNO/IjKBNrr7etYnKAyczBUGh7cs9ixfNKYVheZeK07HJE5UC1MOogXSB3QFbxNob3JRIAABXgZXJesdaeNSOP4Mpnedq091WZv14VLP991n06kD8Uf/OSz0r+bYQrx5r9yAfm1xEL+xkffCHf38hfVk00oBWLv9ZIJ4CxP5kSn6QSjNLC28yeLghAQZ966Xe38/Nh24t7h06iM8Ou1z10G0XZmDAioGR03cjLizKtNMLo6MW2xWTWCk5oE3VVGylo2LbmcGBszDQx9ddYOpKsOfClC5Eq9P6D3xbEXgMe9FCQ4s3YWO5tCs6W/VNjlXUiObuAMEl9YdPvjh4e5nQhOya05/EuKRs8pAgt9FPcB8AIW4fNyi4N3grlPuKIuUAObotP8ttUxEdCBnnBMaxbfJQi0VGbXBmq1KhMQRICurHN0ID88PdZfqAIPUbKkIMKXWjivvkmrDXSAMinwmR0DaD7uVq25Z2fslv0YE4xebtcJVMgYPzb1LPhXB0vRN2rk9nR4A45yY2vHEDT/Yu41px67XeH8andhFYsUZNEzruPGvaI4qZQ5LI6JiRr9vAjnE4Yw== co.ranieri@gmail.com"
}

resource "aws_elb" "web" {
  name = "web-elb"

  subnets         = ["${module.vpc.public_subnet_id}"]
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
    cidr_blocks = ["0.0.0.0/0", "${module.vpc.cidr}"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${module.vpc.cidr}"]
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
