provider "exoscale" {
  key = var.exoscale_key
  secret = var.exoscale_secret
}

/**
 * The AWS provider is used for SOS bucket provisioning
 */
provider "aws" {
  access_key = var.exoscale_key
  secret_key = var.exoscale_secret
  region = var.exoscale_zone
  endpoints {
    s3 = "https://sos-${var.exoscale_zone}.exo.io"
    s3control = "https://sos-${var.exoscale_zone}.exo.io"
  }
  skip_credentials_validation = true
  skip_get_ec2_platforms = true
  skip_metadata_api_check = true
  skip_region_validation = true
  skip_requesting_account_id = true
}

provider "kubernetes" {
  load_config_file = false

  host = local.master_url

  cluster_ca_certificate = tls_self_signed_cert.ca.cert_pem
  client_certificate = tls_locally_signed_cert.admin.cert_pem
  client_key = tls_private_key.admin.private_key_pem
}
