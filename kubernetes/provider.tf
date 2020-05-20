provider "kubernetes" {
  host = var.host
  cluster_ca_certificate = var.ca_certificate
  client_key = var.client_key
  client_certificate = var.client_certificate
}