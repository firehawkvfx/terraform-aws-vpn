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
  description = "The AMI ID of your OpenVPN Access Server image built with packer"
  type = string
}

variable "environment" {
  description = "The environment.  eg: dev/prod"
  type        = string
}

variable "resourcetier" {
  description = "The resource tier uniquely defining the deployment area.  eg: dev/green/blue/main"
  type        = string
}
variable "pipelineid" {
  description = "The pipelineid uniquely defining the deployment instance if using CI.  eg: dev/green/blue/main"
  type        = string
}
variable "conflictkey" {
    description = "The conflictkey is a unique name for each deployement usuallly consisting of the resourcetier and the pipeid."
    type = string
}

variable "deployer_ip_cidr" {
  description = "The IP enabled for SSH access to the vpn access server"
}

variable "consul_cluster_tag_key" {
  description = "The tag the Consul EC2 Instances will look for to automatically discover each other and form a cluster."
  type        = string
}

variable "consul_cluster_name" {
  description = "What to name the Consul server cluster and all of its associated resources"
  type        = string
}

variable "vpn_cidr" {
  description = "The CIDR range that the vpn will assign using DHCP.  These are virtual addresses for routing traffic."
  type        = string
}

variable "onsite_private_subnet_cidr" {
  description = "The subnet CIDR Range of your onsite private subnet. This is also the subnet where your VPN client resides in. eg: 192.168.1.0/24"
  type        = string
}

variable "onsite_public_ip" {
  description = "The public ip address of your onsite location to enable access to security groups and openVPN."
  type = string
}