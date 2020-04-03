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

  user_data = templatefile("${path.module}/user-data.sh", {
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

  /*
  Wait for instance to come up
  */
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "set -e"
    ]
  }
}

locals {
  kube_controller_manager_config = templatefile("${path.module}/kube-controller-manager.kubeconfig", {
    ca_cert = replace(base64encode(var.ca_cert), "\n", "")
    cert = replace(base64encode(tls_locally_signed_cert.controller-manager.cert_pem), "\n", "")
    key = replace(base64encode(tls_private_key.controller-manager.private_key_pem), "\n", "")
    prefix = var.prefix
  })
}
locals {
  kube_scheduler_config = templatefile("${path.module}/kube-scheduler.kubeconfig", {
    ca_cert = replace(base64encode(var.ca_cert), "\n", "")
    cert = replace(base64encode(tls_locally_signed_cert.scheduler.cert_pem), "\n", "")
    key = replace(base64encode(tls_private_key.scheduler.private_key_pem), "\n", "")
    prefix = var.prefix
  })
}

locals {
  encryption_config = templatefile("${path.module}/encryption-config.yaml", {
    ENCRYPTION_KEY =  base64encode(random_string.encryption-key.result)
  })
}

resource "exoscale_nic" "masters" {
  compute_id = element(exoscale_compute.masters.*.id, count.index)
  network_id = exoscale_network.masters.id
  count = 3
}

resource "null_resource" "masters" {
  count = 3
  depends_on = [
    exoscale_compute.masters,
    exoscale_nic.masters
  ]

  /*
  The following section is implemented here because exoscale_compute does not allow for deploying with networks
  attached.
  */
  connection {
    host = element(exoscale_compute.masters.*.ip_address, count.index)
    agent = false
    port = var.ssh_port
    private_key = tls_private_key.initial.private_key_pem
    user = "ubuntu"
  }

  provisioner "remote-exec" {
    inline = [
      templatefile("${path.module}/install-etcd.sh", {
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

  provisioner "remote-exec" {
    inline = [
      templatefile("${path.module}/install-backplane.sh", {
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
      })
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "set -e",
      "sudo userdel -f -r ubuntu"
    ]
  }
}

resource "exoscale_secondary_ipaddress" "ingress" {
  compute_id = exoscale_compute.masters.*.id[count.index]
  ip_address = exoscale_ipaddress.ingress.ip_address
  count = 3
}

resource "exoscale_domain_record" "internal" {
  content = "10.0.0.${count.index}"
  domain = var.service_domain_zone
  name = "master-${count.index}.master.${var.service_domain}"
  record_type = "A"
  count = 3
}

resource "exoscale_domain_record" "public" {
  content = element(exoscale_compute.masters.*.ip_address, count.index)
  domain = var.service_domain_zone
  name = "master-${count.index}.${var.service_domain}"
  record_type = "A"
  count = 3
}
