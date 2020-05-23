resource "kubernetes_namespace" "metallb" {
  //Wait for API to be up
  depends_on = [exoscale_secondary_ipaddress.k8s]
  metadata {
    name = "metallb-system"
    labels = {
      "app" = "metallb"
    }
  }
}
