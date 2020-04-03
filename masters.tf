module "masters" {
  source = "./masters"
  exoscale_key = var.exoscale_key
  exoscale_secret = var.exoscale_secret
  exoscale_zone = var.exoscale_zone
  ssh_port = var.ssh_port
  server_admin_users = var.server_admin_users
  prefix = var.prefix
  security_group_id = exoscale_security_group.k8s.id
  k8s_port = var.k8s_port
  ingress_healthcheck_port = var.ingress_healthcheck_port
  ca_algo = tls_private_key.ca.algorithm
  ca_cert = tls_self_signed_cert.ca.cert_pem
  ca_key = tls_private_key.ca.private_key_pem
  service_domain = var.service_domain
  service_domain_zone = var.service_domain_zone
}
