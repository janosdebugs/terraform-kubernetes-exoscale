resource "null_resource" "deploy_coredns" {
  depends_on = [data.null_data_source.k8s-api]
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=${local_file.admin-kubeconfig.filename} apply -f ${path.module}/files/coredns.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=${local_file.admin-kubeconfig.filename} delete -f ${path.module}/files/coredns.yaml"
    when    = destroy
  }
}
