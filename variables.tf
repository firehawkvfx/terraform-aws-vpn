variable "route_public_domain_name" {
  description = "Defines if a public DNS name is to be used"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "The instance type for the VPN Access Server"
  type        = string
  default     = "t3.micro"
}

variable "sleep" {
  description = "Stop / Start the VPN instance."
  type        = bool
  default     = false
}

variable "openvpn_server_ami" {
  description = "The AMI ID of your PpenVPN Access Server image built with packer"
  type = string
}

variable "resourcetier" {
  description = "The default resource tier - dev/green/blue/main"
}

variable "remote_ip_cidr" {
  description = "The IP enabled for SSH access to the vpn access server"
}