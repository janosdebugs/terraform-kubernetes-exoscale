// region EIP
resource "exoscale_ipaddress" "k8s" {
  zone = var.exoscale_zone
  healthcheck_mode = "http"
  healthcheck_port = var.k8s_healthcheck_port
  healthcheck_path = "/healthz"
  healthcheck_interval = 10
  healthcheck_timeout = 5
  healthcheck_strikes_ok = 3
  healthcheck_strikes_fail = 2
}

resource "exoscale_domain_record" "kubernetes" {
  content = exoscale_ipaddress.k8s.ip_address
  domain = var.service_domain_zone
  name = "kubernetes${local.service_domain_suffix}"
  record_type = "A"
}

locals {
  wait_for_http = var.terraform_os == "windows"?"wait-for-http":"./wait-for-http"
}

resource "exoscale_secondary_ipaddress" "k8s" {
  compute_id = exoscale_compute.masters.*.id[count.index]
  ip_address = exoscale_ipaddress.k8s.ip_address
  count = 3
}
// endregion

// region Certificates
// region Controller-manager certificate
resource "tls_private_key" "controller-manager" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "controller-manager" {
  key_algorithm = tls_private_key.controller-manager.algorithm
  private_key_pem = tls_private_key.controller-manager.private_key_pem
  subject {
    common_name = "system:kube-controller-manager"
  }
}

resource "tls_locally_signed_cert" "controller-manager" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = tls_self_signed_cert.ca.cert_pem
  ca_key_algorithm = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  cert_request_pem = tls_cert_request.controller-manager.cert_request_pem
  validity_period_hours = 8760
}
// endregion
// region Scheduler certificate
resource "tls_private_key" "scheduler" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "scheduler" {
  key_algorithm = tls_private_key.scheduler.algorithm
  private_key_pem = tls_private_key.scheduler.private_key_pem
  subject {
    common_name = "system:kube-scheduler"
  }
}

resource "tls_locally_signed_cert" "scheduler" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = tls_self_signed_cert.ca.cert_pem
  ca_key_algorithm = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  cert_request_pem = tls_cert_request.scheduler.cert_request_pem
  validity_period_hours = 8760
}
// endregion

// region Kubernetes user certificate
resource "tls_private_key" "kubernetes" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "kubernetes" {
  key_algorithm = tls_private_key.kubernetes.algorithm
  private_key_pem = tls_private_key.kubernetes.private_key_pem
  subject {
    common_name = "kubernetes"
    organization = "Kubernetes"
  }
  ip_addresses = [
    "10.32.0.1",
    "10.0.0.1",
    "10.0.0.2",
    "10.0.0.3",
    "127.0.0.1",
    exoscale_ipaddress.k8s.ip_address
  ]
  dns_names = [
    "master-0.masters.${var.service_domain}",
    "master-1.masters.${var.service_domain}",
    "master-2.masters.${var.service_domain}",
    "kubernetes.${var.service_domain}",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.svc.cluster.local"
  ]
}

resource "tls_locally_signed_cert" "kubernetes" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = tls_self_signed_cert.ca.cert_pem
  ca_key_algorithm = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  cert_request_pem = tls_cert_request.kubernetes.cert_request_pem
  validity_period_hours = 8760
}
// endregion
// region Service account certificate
resource "tls_private_key" "service-account" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "service-account" {
  key_algorithm = tls_private_key.service-account.algorithm
  private_key_pem = tls_private_key.service-account.private_key_pem
  subject {
    common_name = "service-accounts"
    organization = "Kubernetes"
  }
}

resource "tls_locally_signed_cert" "service-account" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = tls_self_signed_cert.ca.cert_pem
  ca_key_algorithm = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  cert_request_pem = tls_cert_request.service-account.cert_request_pem
  validity_period_hours = 8760
}
// endregion
// endregion

// region Encryption key
resource "random_string" "encryption-key" {
  length = 32
}
// endregion

// region DNS
resource "exoscale_domain_record" "internal" {
  content = "10.0.0.${count.index}"
  domain = var.service_domain_zone
  name = "${var.prefix}-master-${count.index}.masters${local.service_domain_suffix}"
  record_type = "A"
  ttl = 60
  count = 3
}

resource "exoscale_domain_record" "public" {
  content = element(exoscale_compute.masters.*.ip_address, count.index)
  domain = var.service_domain_zone
  name = "${var.prefix}-master-${count.index}${local.service_domain_suffix}"
  record_type = "A"
  ttl = 60
  count = 3
}
// endregion

// region Privnet
resource "exoscale_network" "masters" {
  name = "${var.prefix}-masters"
  zone = var.exoscale_zone
}

// endregion

// region Kubelet
resource "tls_private_key" "kubelet-master" {
  algorithm = "RSA"
  rsa_bits = 4096
  count = var.workers
}

resource "tls_cert_request" "kubelet-master" {
  key_algorithm = element(tls_private_key.kubelet-master.*.algorithm, count.index)
  private_key_pem = element(tls_private_key.kubelet-master.*.private_key_pem, count.index)
  subject {
    common_name = "system:node:${var.prefix}-master-${count.index}"
    organization = "system:nodes"
  }
  dns_names = [
    "${var.prefix}-master-${count.index}.${var.service_domain}",
    "${var.prefix}-master-${count.index}"
  ]
  count = var.workers
}

resource "tls_locally_signed_cert" "kubelet-master" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = tls_self_signed_cert.ca.cert_pem
  ca_key_algorithm = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  cert_request_pem = element(tls_cert_request.kubelet-master.*.cert_request_pem, count.index)
  validity_period_hours = 8760
  count = var.workers
}
data "template_file" "kubelet-master" {
  template = file("${path.module}/files/kubelet.kubeconfig")
  vars = {
    ca_cert = replace(base64encode(tls_self_signed_cert.ca.cert_pem), "\n", "")
    cert = replace(base64encode(tls_locally_signed_cert.kubelet-master[count.index].cert_pem), "\n", "")
    key = replace(base64encode(tls_private_key.kubelet-master[count.index].private_key_pem), "\n", "")
    prefix = var.prefix
    url = "https://${exoscale_ipaddress.k8s.ip_address}:${var.k8s_port}"
    name = "${var.prefix}-master-${count.index}"
  }
  count = var.workers
}
data "template_file" "kubeproxy-master" {
  template = file("${path.module}/files/kubeproxy.kubeconfig")
  vars = {
    ca_cert = replace(base64encode(tls_self_signed_cert.ca.cert_pem), "\n", "")
    cert = replace(base64encode(tls_locally_signed_cert.kubeproxy.cert_pem), "\n", "")
    key = replace(base64encode(tls_private_key.kubeproxy.private_key_pem), "\n", "")
    url = "https://${exoscale_ipaddress.k8s.ip_address}:${var.k8s_port}"
    prefix = var.prefix
  }
}
// endregion

// region Instances
locals {
  kube_controller_manager_config = templatefile("${path.module}/files/kube-controller-manager.kubeconfig", {
    ca_cert = replace(base64encode(tls_self_signed_cert.ca.cert_pem), "\n", "")
    cert = replace(base64encode(tls_locally_signed_cert.controller-manager.cert_pem), "\n", "")
    key = replace(base64encode(tls_private_key.controller-manager.private_key_pem), "\n", "")
    prefix = var.prefix
  })
}
locals {
  kube_scheduler_config = templatefile("${path.module}/files/kube-scheduler.kubeconfig", {
    ca_cert = replace(base64encode(tls_self_signed_cert.ca.cert_pem), "\n", "")
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

resource "exoscale_affinity" "masters" {
  name = "${var.prefix}-masters"
}



resource "exoscale_compute" "masters" {
  // Wait for SG rule to come up before creating compute resource and also destroy compute before destroying the
  // firewall rule.
  depends_on = [exoscale_security_group_rule.k8s]
  # If you change this, also change initial_cluster_configuration for etcd below
  display_name = "${var.prefix}-master-${count.index}"
  disk_size = 100
  size = "Small"
  key_pair = exoscale_ssh_keypair.initial.name
  template = data.exoscale_compute_template.ubuntu.name
  zone = var.exoscale_zone
  affinity_group_ids = [exoscale_affinity.masters.id]
  security_group_ids = [exoscale_security_group.k8s.id]
  count = 3

  user_data = templatefile("${path.module}/files/master-user-data.sh", {
    ssh_port = var.ssh_port
    users = var.server_admin_users
    privnet_ip = "10.0.0.${count.index + 1}/24"
    name = "${var.prefix}-master-${count.index}"
    domain = var.service_domain
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
        ca_cert = tls_self_signed_cert.ca.cert_pem
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
        ca_cert = tls_self_signed_cert.ca.cert_pem
        ca_key = tls_private_key.ca.private_key_pem
        eip_ip = exoscale_ipaddress.k8s.ip_address
        kubernetes_key = tls_private_key.kubernetes.private_key_pem
        kubernetes_cert = tls_locally_signed_cert.kubernetes.cert_pem
        service_account_key = tls_private_key.service-account.private_key_pem
        service_account_cert = tls_locally_signed_cert.service-account.cert_pem
        kube_controller_manager_config = local.kube_controller_manager_config
        kube_scheduler_config = local.kube_scheduler_config
        encryption_config = local.encryption_config
        prefix = var.prefix
        k8s_port = var.k8s_port
        healthcheck_port = var.k8s_healthcheck_port
      })
    ]
  }

  provisioner "remote-exec" {
    inline = [
      templatefile("${path.module}/files/install-kubelet.sh", {
        ca_cert = tls_self_signed_cert.ca.cert_pem
        prefix = var.prefix
        k8s_port = var.k8s_port
        kubernetes_version = local.kubernetes_version
        containerd_version = local.containerd_version
        critools_version = local.critools_version
        runc_version = local.runc_version
        cni_plugins_version = local.cni_plugins_version
        kubelet_kubeconfig = data.template_file.kubelet-master[count.index].rendered
        kubeproxy_kubeconfig = data.template_file.kubeproxy-master.rendered
        key = tls_private_key.kubelet-master[count.index].private_key_pem
        cert = tls_locally_signed_cert.kubelet-master[count.index].cert_pem
        name = "${var.prefix}-master-${count.index}"
        domain = var.service_domain
        noschedule = 1
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
// endregion

resource "null_resource" "k8s-api" {
  depends_on = [exoscale_secondary_ipaddress.k8s]
  triggers = {
    ip = exoscale_ipaddress.k8s.ip_address
  }
  provisioner "local-exec" {
    working_dir = "${path.module}/bin/${var.terraform_os}"
    command = "${local.wait_for_http} https://${null_resource.k8s-api.triggers["ip"]}:${var.k8s_port}/healthz"
  }
}

data "null_data_source" "k8s-api" {
  inputs = {
    master_url = "https://${null_resource.k8s-api.triggers["ip"]}:${var.k8s_port}"
  }
}

locals {
  master_url = data.null_data_source.k8s-api.outputs["master_url"]
}
