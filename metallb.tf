//Note: this would better be done in Terraform but the Kubernetes support is still very lacking.

resource "random_string" "metallb" {
  length = 128
}

resource "kubernetes_namespace" "metallb" {
  depends_on = [data.null_data_source.k8s-api]
  metadata {
    name = "metallb-system"
  }
}

resource "kubernetes_secret" "metallb" {
  depends_on = [data.null_data_source.k8s-api]
  metadata {
    namespace = kubernetes_namespace.metallb.metadata[0].name
    name = "memberlist"
  }
  data = {
    secretkey = random_string.metallb.result
  }
}

resource "null_resource" "deploy_metallb" {
  depends_on = [data.null_data_source.k8s-api, kubernetes_secret.metallb]
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=${local_file.admin-kubeconfig.filename} apply -f ${path.module}/files/metallb.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=${local_file.admin-kubeconfig.filename} delete -f ${path.module}/files/metallb.yaml"
    when    = destroy
  }
}

resource "kubernetes_config_map" "metallb" {
  metadata {
    namespace = kubernetes_namespace.metallb.metadata[0].name
    name = "config"
  }
  data = {
    config = <<EOF
address-pools:
- name: default
  protocol: layer2
  addresses:
  - ${exoscale_ipaddress.ingress.ip_address}
EOF
  }
}
