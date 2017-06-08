provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "us-west-2"
}

resource "aws_vpc" "training_vpc" {
    cidr_block = "${var.vpc_cidr}"
    enable_dns_hostnames = true
    tags {
        Name = "training_vpc_${var.name_tag}"
        Owner = "${var.owner_tag}"
        UUID = "${var.uuid}"
    }
}

resource "aws_subnet" "vpc_public_subnet" {
    vpc_id = "${aws_vpc.training_vpc.id}"
    map_public_ip_on_launch = true

    cidr_block = "${var.public_subnet_cidr}"

    tags {
        Name = "training_subnet_${var.name_tag}"
        Owner = "${var.owner_tag}"
        UUID = "${var.uuid}"
    }
}

resource "aws_internet_gateway" "vpc_internet_gateway" {
    vpc_id = "${aws_vpc.training_vpc.id}"
    tags {
        Name = "internet_gateway_${var.name_tag}"
        Owner = "${var.owner_tag}"
        UUID = "${var.uuid}"
    }
}

resource "aws_route_table" "vpc_public_subnet_router" {
    vpc_id = "${aws_vpc.training_vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.vpc_internet_gateway.id}"
    }

    tags {
        Name = "public_subnet_router_${var.name_tag}"
        Owner = "${var.owner_tag}"
        UUID = "${var.uuid}"
    }
}

resource "aws_route_table_association" "vpc_public_subnet_router_association" {
    subnet_id = "${aws_subnet.vpc_public_subnet.id}"
    route_table_id = "${aws_route_table.vpc_public_subnet_router.id}"
}


resource "aws_security_group" "training_sg" {
    vpc_id = "${aws_vpc.training_vpc.id}"
    description = "Training security group"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 2222
        to_port = 2222
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 25555
        to_port = 25555
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
  }

    tags {
        Name = "training_sg_${var.name_tag}"
        Owner = "${var.owner_tag}"
        UUID = "${var.uuid}"
    }
}

resource "aws_key_pair" "tango" {
  key_name_prefix = "cf-training-"
  public_key = "${file("${var.platform_public_key_path}")}"
}

resource "aws_instance" "training_jumpbox" {
    ami = "ami-3a32985a"
    instance_type = "m3.xlarge"
    key_name = "${aws_key_pair.tango.key_name}"
    vpc_security_group_ids = ["${aws_security_group.training_sg.id}"]
    subnet_id = "${aws_subnet.vpc_public_subnet.id}"
    associate_public_ip_address = true
    source_dest_check = false

    tags {
        Name = "jumpbox_${var.name_tag}"
        Owner = "${var.owner_tag}"
        UUID = "${var.uuid}"
    }

    connection {
        user = "${var.jumpbox_user}"
        private_key = "${file("${var.platform_private_key_path}")}"
    }

    provisioner "file" {
        source = "${path.module}/scripts/check.sh"
        destination = "/home/${var.jumpbox_user}/check.sh"
    }

    provisioner "file" {
        source = "${path.module}/scripts/settings.sh"
        destination = "/home/${var.jumpbox_user}/settings.sh"
    }

    provisioner "remote-exec" {
        inline = [ "chmod +x /home/${var.jumpbox_user}/check.sh",
                   "chmod +x /home/${var.jumpbox_user}/settings.sh",
                   "sh /home/${var.jumpbox_user}/check.sh",
                   "sh -c '/home/${var.jumpbox_user}/settings.sh'"]
    }
}

output "jumpbox_ip" {
  value = "${aws_instance.training_jumpbox.public_ip}"
}

output "jumpbox_user" {
  value = "${var.jumpbox_user}"
}

output "ssh_port" {
  value = "${var.ssh_port}"
}
