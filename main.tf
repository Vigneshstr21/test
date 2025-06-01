provider "aws" {
    region = "ap-south-1"

  
}

/*resource "aws_instance" "my-first-terraform" {
    ami = "ami-0f58b397bc5c1f2e8"
    instance_type = "t2.micro"
 
}*/


#create vpc
resource "aws_vpc" "prod-vpc" {
  cidr_block       = "192.168.1.0/24"

  tags = {
    Name = "prod"
  }
}

#create internet gateway

resource "aws_internet_gateway" "prod-igw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "prod-igw"
  }
}

#create custom route table
resource "aws_route_table" "prod-rt" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-igw.id
  }


  tags = {
    Name = "prod-rt"
  }
}
#create a subnets

resource "aws_subnet" "prod-sub" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "192.168.1.0/25"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "prod-sub"
  }
}

#associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.prod-sub.id
  route_table_id = aws_route_table.prod-rt.id
}

#create security group to allow port 22,443,80

resource "aws_security_group" "prod-sg" {
  name        = "prod-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  tags = {
    Name = "prod-sg"
  }
}


resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.prod-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.prod-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.prod-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.prod-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.prod-sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


#create internet interface wth an ip in the subnet that was created in 4 step

resource "aws_network_interface" "prod-ni" {
  subnet_id       = aws_subnet.prod-sub.id
  private_ips     = ["192.168.1.10"]
  security_groups = [aws_security_group.prod-sg.id]

}



# Create EBS Volume
  resource "aws_ebs_volume" "strdisk" {
  availability_zone = "ap-south-1a"
  size              = 5
}

# Create EBS Volume
  resource "aws_ebs_volume" "strdisk1" {
  availability_zone = "ap-south-1a"
  size              = 5
}

#create ec2 ubuntu with apcahe2 install
resource "aws_instance" "my-first-terraform" {
    ami = "ami-0c2af51e265bd5e0e"
    instance_type = "t2.micro"
    key_name = "tera"
    tags = {
    Name = "prod-linux"
  }

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.prod-ni.id

    }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y 
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c "echo hi STR > /var/www/html/index.html"
                EOF

 
}

# Attach EBS Volume

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.strdisk.id
  instance_id = aws_instance.my-first-terraform.id
}

resource "aws_volume_attachment" "ebs_att1" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.strdisk1.id
  instance_id = aws_instance.my-first-terraform.id
}


# Assign elsatic ip to the network interface created in step 7

resource "aws_eip" "prod-eip" {
    vpc = true 
    network_interface = aws_network_interface.prod-ni.id
    associate_with_private_ip =  "192.168.1.10"
    depends_on = [ aws_internet_gateway.prod-igw ]

}
