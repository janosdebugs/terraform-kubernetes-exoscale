data "exoscale_compute_template" "ubuntu" {
  zone = var.exoscale_zone
  name = "Linux Ubuntu 18.04 LTS 64-bit"
}