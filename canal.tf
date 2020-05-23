resource "null_resource" "deploy_canal" {
  depends_on = [data.null_data_source.k8s-api]
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=${local_file.admin-kubeconfig.filename} apply -f ${path.module}/files/canal.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=${local_file.admin-kubeconfig.filename} delete -f ${path.module}/files/canal.yaml"
    when    = destroy
  }
}
