resource "tls_private_key" "worker" {
  algorithm = "RSA"
  rsa_bits = 4096
  count = var.workers
}

resource "tls_cert_request" "worker" {
  key_algorithm = element(tls_private_key.worker.*.algorithm, count.index)
  private_key_pem = element(tls_private_key.worker.*.private_key_pem, count.index)
  subject {
    common_name = "system:node:worker-${count.index}"
  }
  dns_names = [
    "worker-${count.index}.${var.service_domain}"
  ]
  count = var.workers
}

resource "tls_locally_signed_cert" "worker" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = var.ca_cert
  ca_key_algorithm = var.ca_algo
  ca_private_key_pem = var.ca_key
  cert_request_pem = element(tls_cert_request.worker.*.cert_request_pem, count.index)
  validity_period_hours = 8760
  count = var.workers
}
