module "kubernetes" {
  source = "./kubernetes"
  host = module.masters.admin_url
  ca_certificate = tls_self_signed_cert.ca.cert_pem
  client_certificate = tls_locally_signed_cert.admin.cert_pem
  client_key = tls_private_key.admin.private_key_pem
}