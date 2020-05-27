resource "null_resource" "deploy_nginx" {
  depends_on = [data.null_data_source.k8s-api, local_file.admin-kubeconfig, local_file.metallb_manifest]
  provisioner "local-exec" {
    command = "kubectl apply --kubeconfig=${path.module}/config/admin.kubeconfig -f ${path.module}/files/nginx-ingress-controller.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl delete --kubeconfig=${path.module}/config/admin.kubeconfig -f ${path.module}/files/nginx-ingress-controller.yaml"
    when = destroy
  }
}
