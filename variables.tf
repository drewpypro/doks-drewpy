variable "digitalocean_token" {
  description = "DigitalOcean API token"
  type        = string
}

variable "region" {
  description = "Region where the resources will be created"
  type        = string
  default     = "nyc1"
}

variable "size" {
  description = "size of the resources that will be created (https://slugs.do-api.dev/)"
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "source_ssh_networks" {
  description = "Source Public IP addresses of your ssh client"
  type        = list(string)
}

variable "game_networks" {
  description = "Source Public IP addresses of your ssh client"
  type        = list(string)
}

