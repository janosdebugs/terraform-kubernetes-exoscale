resource "null_resource" "deploy_coredns" {
  depends_on = [data.null_data_source.k8s-api, local_file.admin-kubeconfig]
  provisioner "local-exec" {
    command = "kubectl apply --kubeconfig=${path.module}/config/admin.kubeconfig -f ${path.module}/files/coredns.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl delete --kubeconfig=${path.module}/config/admin.kubeconfig -f ${path.module}/files/coredns.yaml"
    when = destroy
  }
}
