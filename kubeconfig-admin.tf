resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "admin" {
  key_algorithm = tls_private_key.admin.algorithm
  private_key_pem = tls_private_key.admin.private_key_pem
  subject {
    common_name = "admin"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "admin" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = tls_self_signed_cert.ca.cert_pem
  ca_key_algorithm = tls_self_signed_cert.ca.key_algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  cert_request_pem = tls_cert_request.admin.cert_request_pem
  validity_period_hours = 8760
}

locals {
  admin_config = templatefile("${path.module}/files/admin.kubeconfig", {
    url = local.master_url
    ca_cert = replace(base64encode(tls_self_signed_cert.ca.cert_pem), "\n", "")
    admin_cert = replace(base64encode(tls_locally_signed_cert.admin.cert_pem), "\n", "")
    admin_key = replace(base64encode(tls_private_key.admin.private_key_pem), "\n", "")
    prefix = var.prefix
  })
}

resource "local_file" "admin-kubeconfig" {
  filename = "${path.module}/config/admin.kubeconfig"
  content = local.admin_config
}

resource "local_file" "admin-crt" {
  filename = "${path.module}/config/admin.crt"
  content = tls_locally_signed_cert.admin.cert_pem
}

resource "local_file" "admin-key" {
  filename = "${path.module}/config/admin.pem"
  content = tls_private_key.admin.private_key_pem
}