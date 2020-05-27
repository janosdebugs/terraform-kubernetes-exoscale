// region kube-proxy certificate
resource "tls_private_key" "kubeproxy" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "kubeproxy" {
  key_algorithm = tls_private_key.kubeproxy.algorithm
  private_key_pem = tls_private_key.kubeproxy.private_key_pem
  subject {
    common_name = "system:kube-proxy"
    organization = "system:node-proxier"
  }
}

resource "tls_locally_signed_cert" "kubeproxy" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = tls_self_signed_cert.ca.cert_pem
  ca_key_algorithm = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  cert_request_pem = tls_cert_request.kubeproxy.cert_request_pem
  validity_period_hours = 8760
}
// endregion