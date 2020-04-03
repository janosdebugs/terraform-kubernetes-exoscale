resource "exoscale_domain_record" "internal" {
  content = "10.0.0.${count.index}"
  domain = var.service_domain_zone
  name = "master-${count.index}.master.${var.service_domain}"
  record_type = "A"
  count = 3
}

resource "exoscale_domain_record" "public" {
  content = element(exoscale_compute.masters.*.ip_address, count.index)
  domain = var.service_domain_zone
  name = "master-${count.index}.${var.service_domain}"
  record_type = "A"
  count = 3
}
