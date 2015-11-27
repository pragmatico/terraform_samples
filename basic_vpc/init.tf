# Specify the provider and access details
provider "aws" {
    access_key = "XXXXXXXXXXXX"
    secret_key = "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
	region = "us-east-1"
}

resource "aws_key_pair" "deployer" {
  key_name = "deployer-key" 
  public_key = "ssh-rsa XXXXXXXXXXXX user@host"
}

resource "aws_vpc" "default" {
    cidr_block = "10.1.0.0/16"
    enable_dns_hostnames = true
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.default.id}"
}

resource "aws_subnet" "default" {
  vpc_id = "${aws_vpc.default.id}"
  cidr_block = "10.1.1.0/24"
}

resource "aws_instance" "foo" {
    ami = "ami-60b6c60a"
    instance_type = "t2.micro"
    associate_public_ip_address = true
    key_name = "${aws_key_pair.deployer.key_name}"

	security_groups = ["${aws_security_group.web_instance.id}"]
	subnet_id = "${aws_subnet.default.id}"

    connection {
	    # The default username for our AMI
	    user = "ec2-user"

	    # The path to your keyfile
	    # key_file = "${var.key_path}"
  }
}


resource "aws_security_group" "web_instance" {
	name = "web instance"
	description = "Allow traffic from elb only"

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		#security_groups = ["aws_security_group.default.id"]
	}

	vpc_id = "${aws_vpc.default.id}"
}


resource "aws_route_table" "web_route_table" {
    vpc_id = "${aws_vpc.default.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }

    tags {
        Name = "Public Subnet"
    }
}

resource "aws_route_table_association" "web_route_table" {
    subnet_id = "${aws_subnet.default.id}"
    route_table_id = "${aws_route_table.web_route_table.id}"
}



