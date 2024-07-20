variable "aws_region" {
  description = "AWS region to launch servers."
  default = "us-east-1"
}

variable "domain_name" {
  default = "mydomain.com"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

# Note that the order of the values for public_subnet_cidrs, private_subnet_cidrs, and azs is critical.
# The availability zones will be matched up with the corresponding values in the subnet_cidr arrays.

variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
 type        = list(string)
 description = "Private Subnet CIDR values"
 default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# availability zones
variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# this is just used for convenience. You should replace the IP address with your home address
variable "my_ip_address" {
  description = "this will be used as a safe ip address"
  default = "1.2.3.4/32"
}
