resource "null_resource" "deploy_netpol" {
  depends_on = [data.null_data_source.k8s-api, local_file.admin-kubeconfig]
  provisioner "local-exec" {
    command = "kubectl apply --kubeconfig=${path.module}/config/admin.kubeconfig -f ${path.module}/files/networkpolicy.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl delete --kubeconfig=${path.module}/config/admin.kubeconfig -f ${path.module}/files/networkpolicy.yaml"
    when = destroy
  }
}
