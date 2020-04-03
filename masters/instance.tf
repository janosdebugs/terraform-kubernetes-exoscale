/*
This file will actually provision the three master nodes required for a redundant Kubernetes master.
*/

resource "exoscale_affinity" "masters" {
  name = "${var.prefix}-masters"
}

data "exoscale_compute_template" "ubuntu" {
  zone = var.exoscale_zone
  name = "Linux Ubuntu 18.04 LTS 64-bit"
}

resource "exoscale_compute" "masters" {
  # If you change this, also change initial_cluster_configuration for etcd below
  display_name = "${var.prefix}-master-${count.index}"
  disk_size = 100
  size = "Small"
  key_pair = exoscale_ssh_keypair.masters.name
  template = data.exoscale_compute_template.ubuntu.name
  zone = var.exoscale_zone
  affinity_group_ids = [exoscale_affinity.masters.id]
  security_group_ids = [var.security_group_id]
  count = 3

  user_data = templatefile("${path.module}/files/user-data.sh", {
    ssh_port = var.ssh_port
    users = var.server_admin_users
    privnet_ip = "10.0.0.${count.index + 1}/24"
  })

  connection {
    host = self.ip_address
    agent = false
    port = var.ssh_port
    private_key = tls_private_key.initial.private_key_pem
    user = "ubuntu"
  }

  /**
   * Make sure the network is attached BEFORE etcd comes up.
   */
  provisioner "remote-exec" {
    inline = [
      templatefile("${path.module}/files/attach-network.sh", {
        exocli_version = "1.11.0"
        exoscale_key = var.exoscale_key
        exoscale_secret = var.exoscale_secret
        exoscale_zone = var.exoscale_zone
        network_id = exoscale_network.masters.id
        instance_id = self.id
      })
    ]
  }

  /**
   * Make sure etcd is running
   */
  provisioner "remote-exec" {
    inline = [
      templatefile("${path.module}/files/install-etcd.sh", {
        etcd_version = "3.4.0"
        privnet_cidr = "10.0.0.${count.index + 1}/24"
        privnet_ip = "10.0.0.${count.index + 1}"
        ca_cert = var.ca_cert
        kubernetes_key = tls_private_key.kubernetes.private_key_pem
        kubernetes_cert = tls_locally_signed_cert.kubernetes.cert_pem
        etcd_initial_cluster = "${var.prefix}-master-0=https://10.0.0.1:2380,${var.prefix}-master-1=https://10.0.0.2:2380,${var.prefix}-master-2=https://10.0.0.3:2380"
      })
    ]
  }

  /**
   * Deploy the Kubernetes backplane
   */
  provisioner "remote-exec" {
    inline = [
      templatefile("${path.module}/files/install-backplane.sh", {
        etcd_version = "3.4.0"
        privnet_cidr = "10.0.0.${count.index + 1}/24"
        privnet_ip = "10.0.0.${count.index + 1}"
        kubernetes_version = "1.15.3"
        ca_cert = var.ca_cert
        ca_key = var.ca_key
        eip_ip = exoscale_ipaddress.ingress.ip_address
        kubernetes_key = tls_private_key.kubernetes.private_key_pem
        kubernetes_cert = tls_locally_signed_cert.kubernetes.cert_pem
        service_account_key = tls_private_key.service-account.private_key_pem
        service_account_cert = tls_locally_signed_cert.service-account.cert_pem
        kube_controller_manager_config = local.kube_controller_manager_config
        kube_scheduler_config = local.kube_scheduler_config
        encryption_config = local.encryption_config
        prefix = var.prefix
        k8s_port = var.k8s_port
        healthcheck_port = var.ingress_healthcheck_port
      })
    ]
  }

  /**
   * Delete the ubuntu user used for provisioning
   */
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "set -e",
      "sudo userdel -f -r ubuntu"
    ]
  }
}
