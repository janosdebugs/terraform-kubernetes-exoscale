/*
This file is responsible for the initial keypair used during node deployment. This key is deleted in the final phase
of the deployment.
*/

resource "tls_private_key" "initial" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "exoscale_ssh_keypair" "masters" {
  name = "${var.prefix}-masters"
  public_key = replace(tls_private_key.initial.public_key_openssh, "\n", "")
}
