resource "kubernetes_service_account" "coredns" {
  metadata {
    name = "coredns"
    namespace = "kube-system"
  }
}
resource "kubernetes_cluster_role" "coredns" {
  metadata {
    labels = {
      "kubernetes.io/bootstrapping" = "rbac-defaults"
    }
    name = "system:coredns"
  }
  rule {
    api_groups = [
      ""
    ]
    resources = [
      "endpoints",
      "services",
      "pods",
      "namespaces"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }
  rule {
    api_groups = [
      ""
    ]
    resources = [
      "nodes"
    ]
    verbs = [
      "get"
    ]
  }
}
resource "kubernetes_cluster_role_binding" "coredns" {
  metadata {
    annotations = {
      "rbac.authorization.kubernetes.io/autoupdate" = "true"
    }
    labels = {
      "kubernetes.io/bootstrapping" = "rbac-defaults"
    }
    name = "system:coredns"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "system:coredns"
  }
  subject {
    kind = "ServiceAccount"
    name = "coredns"
    namespace = "kube-system"
  }
}
resource "kubernetes_config_map" "coredns" {
  metadata {
    name = "coredns"
    namespace = "kube-system"
  }
  data = {
    Corefile = <<EOF
.:53 {
    errors
    health
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
      pods insecure
      fallthrough in-addr.arpa ip6.arpa
    }
    prometheus :9153
    cache 30
    loop
    reload
    loadbalance
}
EOF
  }
}

resource "kubernetes_deployment" "coredns" {
  metadata {
    name = "coredns"
    namespace = "kube-system"
    labels = {
      "k8s-app" = "kube-dns"
      "kubernetes.io/name" = "CoreDNS"
    }
  }
  spec {
    replicas = 2
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_unavailable = 1
      }
    }
    selector {
      match_labels = {
        "k8s-app": "kube-dns"
      }
    }
    template {
      metadata {
        labels = {
          "k8s-app": "kube-dns"
        }
      }
      spec {
        priority_class_name = "system-cluster-critical"
        service_account_name = kubernetes_service_account.coredns.metadata[0].name
        toleration {
          key = "CriticalAddonsOnly"
          operator = "Exists"
        }
        node_selector = {
          "beta.kubernetes.io/os" = "Linux"
        }
        container {
          name = "coredns"
          image = "coredns/coredns:1.6.2"
          image_pull_policy = "IfNotPresent"
          resources {
            limits {
              memory = "170Mi"
            }
            requests {
              cpu = "100m"
              memory = "70Mi"
            }
          }
          args = [
            "-conf",
            "/etc/coredns/Corefile"]
          volume_mount {
            name = "config-volume"
            mount_path = "/etc/coredns"
            read_only = true
          }
          port {
            container_port = 53
            name = "dns"
            protocol = "UDP"
          }
          port {
            container_port = 53
            name = "dns-tcp"
            protocol = "TCP"
          }
          port {
            container_port = 9153
            name = "metrics"
            protocol = "TCP"
          }
          security_context {
            allow_privilege_escalation = false
            capabilities {
              add = [
                "NET_BIND_SERVICE"
              ]
              drop = [
                "all"
              ]
            }
            read_only_root_filesystem = true
          }
          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
              scheme = "HTTP"
            }
            initial_delay_seconds = 60
            timeout_seconds = 5
            success_threshold = 1
            failure_threshold = 5
          }
          readiness_probe {
            http_get {
              path = "/ready"
              port = 8181
              scheme = "HTTP"
            }
          }
        }
        dns_policy = "Default"
        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.coredns.metadata[0].name
            items {
              key = "Corefile"
              path = "Corefile"
            }
          }
        }
      }
    }
  }
}
