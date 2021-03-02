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