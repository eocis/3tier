# Cidrs
variable "cidrs" {
    type = map(string)
    default = {
      0 = "10.0.0.0/24"
      1 = "10.0.1.0/24"
      2 = "10.0.2.0/24"
      3 = "10.0.3.0/24"
    }
}

# Instance Type
variable "instance" {
  type = map(string)
  default = {
    "Bastion" = "t2.micro"
    "Front-End" = "t2.micro"
    "Back-End" = "t2.micro"
  }
  
}

# user_data
variable "Front-End_instance_template" {    # Front-End Instance user_data configure
  type = string
  default = <<EOF
#!/bin/bash -xe
apt update -y
apt install -y apache2
EOF
}

variable "Back-End_instance_template" {    # Front-End Instance user_data configure
  type = string
  default = <<EOF
#!/bin/bash -xe
apt update -y
apt install -y python3 python3-pip apache2
pip3 install flask
EOF
}