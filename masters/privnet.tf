/*
This file provisions a private networks for use with the Kubernetes masters only. This is done such that the
IP address of the masters can be deterministic so etcd can connect together.
*/

resource "exoscale_network" "masters" {
  name = "${var.prefix}-masters"
  zone = var.exoscale_zone
}
