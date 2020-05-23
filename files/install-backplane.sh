#!/bin/bash

set -e

wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v${kubernetes_version}/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v${kubernetes_version}/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v${kubernetes_version}/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v${kubernetes_version}/bin/linux/amd64/kubectl"
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

sudo mkdir -p /var/lib/kubernetes/
sudo mkdir -p /etc/kubernetes/config/

cat <<EOF | sudo tee /var/lib/kubernetes/ca.pem >/dev/null
${ca_cert}
EOF

cat <<EOF | sudo tee /var/lib/kubernetes/ca-key.pem >/dev/null
${ca_key}
EOF

cat <<EOF | sudo tee /var/lib/kubernetes/kubernetes.pem >/dev/null
${kubernetes_cert}
EOF

cat <<EOF | sudo tee /var/lib/kubernetes/kubernetes-key.pem >/dev/null
${kubernetes_key}
EOF

cat <<EOF | sudo tee /var/lib/kubernetes/service-account.pem >/dev/null
${service_account_cert}
EOF

cat <<EOF | sudo tee /var/lib/kubernetes/service-account-key.pem >/dev/null
${service_account_key}
EOF

cat <<EOF | sudo tee /var/lib/kubernetes/encryption-config.yaml >/dev/null
${encryption_config}
EOF

ADVERTISE_ADDRESS="${eip_ip}"

# region API Server
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service >/dev/null
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=$${ADVERTISE_ADDRESS} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://10.0.0.1:2379,https://10.0.0.2:2379,https://10.0.0.3:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
# endregion

# region Controller-Manager
cat <<EOF | sudo tee /var/lib/kubernetes/kube-controller-manager.kubeconfig >/dev/null
${kube_controller_manager_config}
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service >/dev/null
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.244.0.0/16 \\
  --cluster-name=${prefix} \\
  --allocate-node-cidrs=true \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
# endregion

# region Scheduler
cat <<EOF | sudo tee /var/lib/kubernetes/kube-scheduler.kubeconfig >/dev/null
${kube_scheduler_config}
EOF

cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml >/dev/null
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service >/dev/null
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
# endregion

sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

sudo apt-get update
sudo apt-get install -y nginx
cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      ${healthcheck_port};
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:${k8s_port}/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF
sudo mv kubernetes.default.svc.cluster.local /etc/nginx/sites-available/kubernetes.default.svc.cluster.local
sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

sudo systemctl restart nginx
sudo systemctl enable nginx

for i in $(seq 1 30); do
  set +e
  curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1:${healthcheck_port}/healthz
  if [ $? -eq 0 ]; then
    exit 0
  fi
  set -e
  sleep 1
done
echo "Kubernetes backplane failed to come up within 30 seconds!" >&2
exit 1
