# Specify the provider and access details
provider "aws" {
    access_key = "XXXXXXXXXXXX"
    secret_key = "XXXXXXXXXXXXXXX"
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




resource "aws_security_group" "web_instance" {
	name = "web instance"
	description = "Public subnet"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 8080
        to_port = 8080
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
        from_port = 8161
        to_port = 8161
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 61616
        to_port = 61616
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }    
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }   

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 8161
        to_port = 8161
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 61616
        to_port = 61616
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }    
    egress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_security_group" "nat" {
	name = "nat instance"
	description = "Allow all TCP traffic from app tier"

	ingress {
		from_port = 0
		to_port = 65535
		protocol = "tcp"
		security_groups = ["${aws_security_group.web_instance.id}"]
	}

	vpc_id = "${aws_vpc.default.id}"
}



# create instance

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
	    private_key = "${file("/Users/jmbataller/Downloads/id_rsa")}"
	}

	# user_data = "${file("init-remote.sh")}"

    provisioner "remote-exec" {
        inline = [
          "sudo yum -y update",
          "sudo yum -y remove java-1.7.0-openjdk",
          "sudo yum -y install java-1.8.0-openjdk.x86_64"
        ]
    }

    provisioner "file" {
        source = "../../target/notifications-0.0.1-SNAPSHOT.jar"
        destination = "/home/ec2-user/notifications-service.jar"
    }

    provisioner "file" {
        source = "../../config/properties/notifications-config.properties"
        destination = "/home/ec2-user/notifications-config.properties"
    }

    provisioner "file" {
        source = "../../config/properties/subscribers.properties"
        destination = "/home/ec2-user/subscribers.properties"
    }

    provisioner "file" {
        source = "run.sh"
        destination = "/home/ec2-user/run.sh"
    }

    /*
	provisioner "remote-exec" {
        script = "${file("run.sh")}"
    }
    */

	provisioner "local-exec" {
        command = "echo ${aws_instance.foo.public_ip} > ip.txt"
    }

    provisioner "local-exec" {
        command = "ssh -o StrictHostKeyChecking=no ec2-user@${aws_instance.foo.public_ip} 'nohup java -DNOTIFICATIONS_PROPS=/home/ec2-user/notifications-config.properties -DSUBSCRIBERS_PROPS=/home/ec2-user/subscribers.properties -DACTIVEMQ_PRIMARY_HOST=${aws_instance.mb.public_ip} -DACTIVEMQ_PRIMARY_PORT=61616 -jar /home/ec2-user/notifications-service.jar > /dev/null 2>&1 &'"
    }

  	#Instance tags
  	tags {
    	Name = "notifications-service"
  	}

    depends_on = ["aws_instance.mb"]
}


resource "aws_instance" "mb" {
    ami = "ami-60b6c60a"
    instance_type = "t2.micro"
    associate_public_ip_address = true
    key_name = "${aws_key_pair.deployer.key_name}"

    security_groups = ["${aws_security_group.web_instance.id}"]
    subnet_id = "${aws_subnet.default.id}"

    connection {
        # The default username for our AMI
        user = "ec2-user"
        private_key = "${file("/Users/jmbataller/Downloads/id_rsa")}"
    }

    # user_data = "${file("init-remote.sh")}"

    provisioner "remote-exec" {
        inline = [
          "sudo yum -y update",
          "sudo yum -y remove java-1.7.0-openjdk",
          "sudo yum -y install java-1.8.0-openjdk.x86_64",
          "wget https://archive.apache.org/dist/activemq/5.9.1/apache-activemq-5.9.1-bin.tar.gz",
          "tar zxvf apache-activemq-5.9.1-bin.tar.gz"
        ]
    }

    provisioner "local-exec" {
        command = "echo ${aws_instance.mb.public_ip} > mb-ip.txt"
    }

    provisioner "local-exec" {
        command = "echo mb=${aws_instance.mb.public_ip}"
    }

    provisioner "local-exec" {
        command = "ssh -o StrictHostKeyChecking=no ec2-user@${aws_instance.mb.public_ip} '/home/ec2-user/apache-activemq-5.9.1/bin/activemq start'"
    }

    #Instance tags
    tags {
        Name = "notifications-activemq"
    }
}


/*
resource "aws_eip" "ip" {
    instance = "${aws_instance.foo.id}"
    depends_on = ["aws_instance.foo"]
}

output "ip" {
    value = "${aws_eip.ip.public_ip}"
}
*/




