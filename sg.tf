resource "exoscale_security_group" "k8s" {
  name = var.prefix
}

/*
Internal traffic rule. We allow everything since the job of limiting access should be done inside k8s using network
policies.
*/
resource "exoscale_security_group_rule" "internal" {
  type = "INGRESS"
  security_group_id = exoscale_security_group.k8s.id
  protocol = "ALL"
  user_security_group_id = exoscale_security_group.k8s.id
  description = "Managed by Terraform!"
}

/*
ICMP fragmentation needed allowed. This is needed for non-standard MTU connections anywhere the services in Kubernetes
send data to.
*/
resource "exoscale_security_group_rule" "fragmentation" {
  type = "INGRESS"
  security_group_id = exoscale_security_group.k8s.id
  protocol = "ICMP"
  cidr = "0.0.0.0/0"
  icmp_type = 3
  icmp_code = 4
  description = "Managed by Terraform!"
}

/*
SSH access rules.
*/
resource "exoscale_security_group_rule" "ssh" {
  type = "INGRESS"
  security_group_id = exoscale_security_group.k8s.id
  protocol = "TCP"
  start_port = var.ssh_port
  end_port = var.ssh_port
  cidr = element(var.firewall_allowed_ssh, count.index)
  count = length(var.firewall_allowed_ssh)
}

/*
K8S API access.
*/
resource "exoscale_security_group_rule" "k8s" {
  type = "INGRESS"
  security_group_id = exoscale_security_group.k8s.id
  protocol = "TCP"
  start_port = var.k8s_port
  end_port = var.k8s_port
  cidr = element(var.firewall_allowed_k8s, count.index)
  count = length(var.firewall_allowed_k8s)
}

/*
Allowed TCP ports for ingress.
*/
resource "exoscale_security_group_rule" "ingress-tcp" {
  type = "INGRESS"
  security_group_id = exoscale_security_group.k8s.id
  protocol = "TCP"
  start_port = element(var.ingress_allowed_tcp_ports, count.index)
  end_port = element(var.ingress_allowed_tcp_ports, count.index)
  cidr = "0.0.0.0/0"
  count = length(var.ingress_allowed_tcp_ports)
}

resource "exoscale_security_group_rule" "ingress-udp" {
  type = "INGRESS"
  security_group_id = exoscale_security_group.k8s.id
  protocol = "UDP"
  start_port = element(var.ingress_allowed_udp_ports, count.index)
  end_port = element(var.ingress_allowed_udp_ports, count.index)
  cidr = "0.0.0.0/0"
  count = length(var.ingress_allowed_udp_ports)
}

resource "exoscale_security_group_rule" "healthcheck" {
  type = "INGRESS"
  security_group_id = exoscale_security_group.k8s.id
  protocol = "TCP"
  start_port = var.ingress_healthcheck_port
  end_port = var.ingress_healthcheck_port
  cidr = "0.0.0.0/0"
}
