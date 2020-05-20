resource "kubernetes_cluster_role" "apiserver-to-kubelet" {
  metadata {
    annotations = {
      "rbac.authorization.kubernetes.io/autoupdate": "true"
    }
    labels = {
      "kubernetes.io/bootstrapping": "rbac-defaults"
    }
    name = "system:kube-apiserver-to-kubelet"
  }
  rule {
    api_groups = [""]
    resources = [
      "nodes/proxy",
      "nodes/stats",
      "nodes/log",
      "nodes/spec",
      "nodes/metrics"
    ]
    verbs = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "apiserver-to-kubelet" {
  metadata {
    name = "system:kube-apiserver"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = kubernetes_cluster_role.apiserver-to-kubelet.metadata[0].name
  }
  subject {
    api_group = "rbac.authorization.k8s.io"
    kind = "User"
    name = "kubernetes"
  }
}