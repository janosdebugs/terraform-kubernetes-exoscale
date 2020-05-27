resource "random_string" "metallb_secret" {
  length = 32
}

resource "local_file" "metallb_manifest" {
  filename = "${path.module}/config/metallb.yaml"
  content = templatefile("${path.module}/files/metallb.yaml", {
    secretkey = base64encode(random_string.metallb_secret.result)
  })
}

resource "null_resource" "deploy_metallb" {
  depends_on = [data.null_data_source.k8s-api, local_file.admin-kubeconfig, local_file.metallb_manifest]
  provisioner "local-exec" {
    command = "kubectl apply --kubeconfig=${path.module}/config/admin.kubeconfig -f ${path.module}/config/metallb.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl delete --kubeconfig=${path.module}/config/admin.kubeconfig -f ${path.module}/files/metallb.yaml"
    when = destroy
  }
}
