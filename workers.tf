// region Kubelet certificate
resource "tls_private_key" "kubelet" {
  algorithm = "RSA"
  rsa_bits = 4096
  count = var.workers
}

resource "tls_cert_request" "kubelet" {
  key_algorithm = element(tls_private_key.kubelet.*.algorithm, count.index)
  private_key_pem = element(tls_private_key.kubelet.*.private_key_pem, count.index)
  subject {
    common_name = "system:node:${var.prefix}-worker-${count.index}"
    organization = "system:nodes"
  }
  dns_names = [
    "${var.prefix}-worker-${count.index}.${var.service_domain}",
    "${var.prefix}-worker-${count.index}"
  ]
  count = var.workers
}

resource "tls_locally_signed_cert" "kubelet" {
  allowed_uses = [
    "signing", "key encipherment", "server auth", "client auth"
  ]
  ca_cert_pem = tls_self_signed_cert.ca.cert_pem
  ca_key_algorithm = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  cert_request_pem = element(tls_cert_request.kubelet.*.cert_request_pem, count.index)
  validity_period_hours = 8760
  count = var.workers
}
// endregion

// region EIP
resource "exoscale_ipaddress" "ingress" {
  zone = var.exoscale_zone
}

resource "exoscale_domain_record" "ingress" {
  content = exoscale_ipaddress.ingress.ip_address
  domain = var.service_domain_zone
  name = local.service_domain_stub
  ttl = 60
  record_type = "A"
}

resource "exoscale_secondary_ipaddress" "ingress" {
  compute_id = exoscale_compute.worker.*.id[count.index]
  ip_address = exoscale_ipaddress.ingress.ip_address
  count = var.workers
}
// endregion

// region Kubelet authorization
resource "kubernetes_cluster_role" "apiserver-to-kubelet" {
  depends_on = [exoscale_secondary_ipaddress.k8s]
  metadata {
    annotations = {
      "rbac.authorization.kubernetes.io/autoupdate": "true"
    }
    labels = {
      "kubernetes.io/bootstrapping": "rbac-defaults"
    }
    name = "system:kube-apiserver-to-kubelet"
  }
  rule {
    api_groups = [""]
    resources = [
      "nodes/proxy",
      "nodes/stats",
      "nodes/log",
      "nodes/spec",
      "nodes/metrics"
    ]
    verbs = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "apiserver-to-kubelet" {
  depends_on = [exoscale_secondary_ipaddress.k8s]
  metadata {
    name = "system:kube-apiserver"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = kubernetes_cluster_role.apiserver-to-kubelet.metadata[0].name
  }
  subject {
    api_group = "rbac.authorization.k8s.io"
    kind = "User"
    name = "kubernetes"
  }
}
// endregion

// region Instance
data "template_file" "kubelet" {
  template = file("${path.module}/files/kubelet.kubeconfig")
  vars = {
    ca_cert = replace(base64encode(tls_self_signed_cert.ca.cert_pem), "\n", "")
    cert = replace(base64encode(tls_locally_signed_cert.kubelet[count.index].cert_pem), "\n", "")
    key = replace(base64encode(tls_private_key.kubelet[count.index].private_key_pem), "\n", "")
    prefix = var.prefix
    url = local.master_url
    name = "${var.prefix}-worker-${count.index}"
  }
  count = var.workers
}
data "template_file" "kubeproxy" {
  template = file("${path.module}/files/kubeproxy.kubeconfig")
  vars = {
    ca_cert = replace(base64encode(tls_self_signed_cert.ca.cert_pem), "\n", "")
    cert = replace(base64encode(tls_locally_signed_cert.kubeproxy.cert_pem), "\n", "")
    key = replace(base64encode(tls_private_key.kubeproxy.private_key_pem), "\n", "")
    url = local.master_url
    prefix = var.prefix
  }
}

resource "exoscale_affinity" "workers" {
  name = "${var.prefix}-workers"
}

resource "exoscale_compute" "worker" {
  depends_on = [
    kubernetes_cluster_role_binding.apiserver-to-kubelet
  ]

  display_name = "${var.prefix}-worker-${count.index}"
  disk_size = 100
  size = "Small"
  key_pair = exoscale_ssh_keypair.initial.name
  template = data.exoscale_compute_template.ubuntu.name
  zone = var.exoscale_zone
  affinity_group_ids = [exoscale_affinity.workers.id]
  security_group_ids = [exoscale_security_group.k8s.id]
  count = var.workers

  user_data = templatefile("${path.module}/files/worker-user-data.sh", {
    ssh_port = var.ssh_port
    users = var.server_admin_users
    name = "${var.prefix}-worker-${count.index}"
    domain = var.service_domain
    workernet_ip = "10.1.1.${count.index + 1}/16"
  })

  connection {
    host = self.ip_address
    agent = false
    port = var.ssh_port
    private_key = tls_private_key.initial.private_key_pem
    user = "ubuntu"
  }

  /**
   * Deploy the Kubernetes backplane
   */
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
        kubelet_kubeconfig = data.template_file.kubelet[count.index].rendered
        kubeproxy_kubeconfig = data.template_file.kubeproxy.rendered
        key = tls_private_key.kubelet[count.index].private_key_pem
        cert = tls_locally_signed_cert.kubelet[count.index].cert_pem
        name = "${var.prefix}-worker-${count.index}"
        domain = var.service_domain
        noschedule = 0
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
resource "exoscale_domain_record" "worker" {
  content = exoscale_compute.worker[count.index].ip_address
  domain = var.service_domain_zone
  name = "${var.prefix}-worker-${count.index}${local.service_domain_suffix}"
  record_type = "A"
  ttl = 60
  count = var.workers
}
// endregion