locals {
  kube_controller_manager_config = templatefile("${path.module}/files/kube-controller-manager.kubeconfig", {
    ca_cert = replace(base64encode(var.ca_cert), "\n", "")
    cert = replace(base64encode(tls_locally_signed_cert.controller-manager.cert_pem), "\n", "")
    key = replace(base64encode(tls_private_key.controller-manager.private_key_pem), "\n", "")
    prefix = var.prefix
  })
}
locals {
  kube_scheduler_config = templatefile("${path.module}/files/kube-scheduler.kubeconfig", {
    ca_cert = replace(base64encode(var.ca_cert), "\n", "")
    cert = replace(base64encode(tls_locally_signed_cert.scheduler.cert_pem), "\n", "")
    key = replace(base64encode(tls_private_key.scheduler.private_key_pem), "\n", "")
    prefix = var.prefix
  })
}

locals {
  encryption_config = templatefile("${path.module}/files/encryption-config.yaml", {
    ENCRYPTION_KEY =  base64encode(random_string.encryption-key.result)
  })
}
