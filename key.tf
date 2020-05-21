resource "tls_private_key" "initial" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "exoscale_ssh_keypair" "initial" {
  name = var.prefix
  public_key = replace(tls_private_key.initial.public_key_openssh, "\n", "")
}
