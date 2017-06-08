variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "platform_public_key_path" {}
variable "platform_private_key_path" {}

variable "owner_tag" {
    description = "User email from platform"
}

variable "name_tag" {
    description = "Name of infrastructure from platform"
}

variable "uuid" {
    description = "Unique prefix for all resources"
}

variable "jumpbox_user" {
    default = "ubuntu"
}

variable "ssh_port" {
    default = "22"
}

variable "vpc_cidr" {
    description = "CIDR for the whole VPC"
    default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    description = "CIDR for the Public Subnet"
    default = "10.0.0.0/24"
}
