resource "exoscale_ipaddress" "ingress" {
  zone = var.exoscale_zone
  healthcheck_mode = "tcp"
  healthcheck_port = var.ingress_healthcheck_port
  healthcheck_interval = 10
  healthcheck_timeout = 5
  healthcheck_strikes_ok = 3
  healthcheck_strikes_fail = 2
}

resource "exoscale_domain_record" "kubernetes" {
  content = exoscale_ipaddress.ingress.ip_address
  domain = var.service_domain_zone
  name = "kubernetes.${var.service_domain}"
  record_type = "A"
}
