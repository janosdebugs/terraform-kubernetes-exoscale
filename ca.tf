resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm     = "RSA"
  private_key_pem   = tls_private_key.ca.private_key_pem
  is_ca_certificate = true

  subject {
    common_name         = "Kubernetes CA"
  }

  validity_period_hours = 87659

  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
    "client_auth",
    "server_auth"
  ]
}

resource "local_file" "ca-key" {
  filename = "${var.output_config_directory}/ca.pem"
  content = tls_private_key.admin.private_key_pem
  count = var.output_config == true?1:0
}

resource "local_file" "ca-cert" {
  filename = "${var.output_config_directory}/ca.crt"
  content = tls_self_signed_cert.ca.cert_pem
  count = var.output_config == true?1:0
}
