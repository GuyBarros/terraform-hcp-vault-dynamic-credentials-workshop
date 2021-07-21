
locals {
  # Common tags to be assigned to all resources
  common_tags = {
    Name      = var.name
    owner     = var.owner
    se-region = var.region
    terraform = true
    purpose   = var.purpose
    ttl       = "4h"
  }
}

#Tags
variable "name" {
  description = <<EOH
Name to be added to the default tags
EOH
}

variable "owner" {
  description = <<EOH
owner to be added to the default tags
EOH
}

variable "purpose" {
  description = <<EOH
purpose to be added to the default tags
EOH
}


#Enviroment
variable "namespace" {
  description = <<EOH
this is the differantiates different HCP Instruqt workshop deployment on the same subscription, everycluster should have a different value
EOH
  default     = "hcpvaultworkshop"
}

variable "region" {
  description = "The region to create resources."
  default     = "eu-west-2"
}

variable "public_key" {
  description = "The contents of the SSH public key to use for connecting to the cluster."
}

variable "vpc_cidr_block" {
  description = "The top-level CIDR block for the VPC."
  default     = "10.1.0.0/16"
}

variable "cidr_blocks" {
  description = "The CIDR blocks to create the workstations in."
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}


variable "instance_type_worker" {
  description = "The type(size) of data servers (consul, nomad, etc)."
  default     = "t3.small"
}


#Security
variable "host_access_ip" {
  description = "CIDR blocks allowed to connect via SSH on port 22"
  type        = list(string)
  default     = []
}

#HCP
variable "hashi_region" {
  description = "the region the owner belongs in.  e.g. NA-WEST-ENT, EU-CENTRAL"
  default     = "EMEA"
}


variable "hcp_cluster_tier" {
  description = "the HCP Consul Cluster tier that you  want to use"
  default     = "development"
}

variable "hcp_hvn_id" {
  description = "the Hashicorp Virtual Network id you want use"
  default     = "hcpvaultworkshop"
}
