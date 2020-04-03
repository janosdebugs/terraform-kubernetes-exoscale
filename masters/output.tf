output "admin_url" {
  value = "https://${exoscale_ipaddress.ingress.ip_address}:${var.k8s_port}"
}