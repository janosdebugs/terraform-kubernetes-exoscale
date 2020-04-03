variable "exoscale_key" {
  description = "Exoscale API key"
}
variable "exoscale_secret" {
  description = "Exoscale API secret"
}

variable "exoscale_zone" {
  description = "Exoscale zone (lower case)"
}

variable "ssh_port" {
  description = "SSH port to use for servers. Do not set to 22."
}

variable "server_admin_users" {
  description = "Server admin users and their SSH key"
  type = map(string)
}

variable "prefix" {
  description = "Resource prefix"
}

variable "k8s_port" {
  description = "Kubernetes API port."
  type = number
}

variable "security_group_id" {
  description = "Exoscale security group ID"
}

variable "ingress_healthcheck_port" {
  description = "Kubernetes healthcheck port."
  type = number
}

variable "ca_key" {
  description = "CA private key"
}

variable "ca_algo" {
  description = "CA algorithm"
}

variable "ca_cert" {
  description = "CA certificate"
}

variable "service_domain" {
  description = "Service domain name to use for the Kubernetes cluster"
}

variable "service_domain_zone" {
  description = "DNS zone on Exoscale DNS to use for the Kubernetes cluster"
}