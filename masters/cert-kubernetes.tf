resource "tls_private_key" "kubernetes" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "kubernetes" {
  key_algorithm = tls_private_key.kubernetes.algorithm
  private_key_pem = tls_private_key.kubernetes.private_key_pem
  subject {
    common_name = "kubernetes"
  }
  ip_addresses = [
    "10.0.0.1",
    "10.0.0.2",
    "10.0.0.3",
    "127.0.0.1",
    exoscale_ipaddress.ingress.ip_address
  ]
  dns_names = [
    "master-0.master.${var.service_domain}",
    "master-1.master.${var.service_domain}",
    "master-2.master.${var.service_domain}",
    "kubernetes.${var.service_domain}",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.svc.cluster.local"
  ]
}

resource "tls_locally_signed_cert" "kubernetes" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = var.ca_cert
  ca_key_algorithm = var.ca_algo
  ca_private_key_pem = var.ca_key
  cert_request_pem = tls_cert_request.kubernetes.cert_request_pem
  validity_period_hours = 8760
}
