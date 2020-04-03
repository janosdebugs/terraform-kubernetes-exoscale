resource "tls_private_key" "service-account" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "service-account" {
  key_algorithm = tls_private_key.service-account.algorithm
  private_key_pem = tls_private_key.service-account.private_key_pem
  subject {
    common_name = "service-accounts"
  }
}

resource "tls_locally_signed_cert" "service-account" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = var.ca_cert
  ca_key_algorithm = var.ca_algo
  ca_private_key_pem = var.ca_key
  cert_request_pem = tls_cert_request.service-account.cert_request_pem
  validity_period_hours = 8760
}
