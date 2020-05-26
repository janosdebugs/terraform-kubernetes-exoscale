resource "null_resource" "deploy_namespace" {
  depends_on = [data.null_data_source.k8s-api, local_file.admin-kubeconfig]
  provisioner "local-exec" {
    command = "kubectl apply --kubeconfig=${path.module}/config/admin.kubeconfig -f ${path.module}/files/namespace.yaml"
  }
}
