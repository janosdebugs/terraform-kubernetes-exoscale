#!/bin/bash

set -e

cd /tmp

wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v${critools_version}/crictl-v${critools_version}-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v${runc_version}/runc.amd64 \
  https://github.com/containerd/containerd/releases/download/v${containerd_version}/containerd-${containerd_version}.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v${kubernetes_version}/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v${kubernetes_version}/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v${kubernetes_version}/bin/linux/amd64/kubelet

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes \
  /etc/containerd

mkdir containerd
tar -xvf crictl-v${critools_version}-linux-amd64.tar.gz
tar -xvf containerd-${containerd_version}.linux-amd64.tar.gz -C containerd
sudo mv runc.amd64 runc
chmod +x crictl kubectl kube-proxy kubelet runc
sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
sudo mv containerd/bin/* /bin/

# region Containerd
cat << EOF | sudo tee /etc/containerd/config.toml >/dev/null
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF

cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
# endregion

# region Kubelet
cat <<EOF | sudo tee /var/lib/kubernetes/ca.pem >/dev/null
${ca_cert}
EOF

cat <<EOF | sudo tee /var/lib/kubelet/${name}-key.pem >/dev/null
${key}
EOF

cat <<EOF | sudo tee /var/lib/kubelet/${name}.pem >/dev/null
${cert}
EOF

cat <<EOF | sudo tee /var/lib/kubelet/kubeconfig >/dev/null
${kubelet_kubeconfig}
EOF

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${name}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${name}-key.pem"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
# endregion

# region Kubelet
cat <<EOF | sudo tee /var/lib/kube-proxy/kubeconfig
${kubeproxy_kubeconfig}
EOF

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
# endregion

# region Services
sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy

UP=0
for i in $(seq 1 30); do
  set +e
  systemctl is-active --quiet kubelet
  if [ $? -eq 0 ]; then
    UP=1
    break
  fi
  set -e
done
if [ $UP -eq 0 ]; then
  echo "The kubelet service is not active"
fi
for i in $(seq 1 30); do
  set +e
  curl -i http://127.0.0.1:10248/healthz
  if [ $? -eq 0 ]; then
    exit 0
  fi
  set -e
  sleep 1
done
echo "kubelet failed to come up within 30 seconds!" >&2

UP=0
for i in $(seq 1 30); do
  set +e
  systemctl is-active --quiet kube-proxy
  if [ $? -eq 0 ]; then
    UP=1
    break
  fi
  set -e
done
if [ $UP -eq 0 ]; then
  echo "The kube-proxy service is not active"
fi

for i in $(seq 1 30); do
  set +e
  curl -i http://127.0.0.1:10256/healthz
  if [ $? -eq 0 ]; then
    exit 0
  fi
  set -e
  sleep 1
done
echo "kube-proxy failed to come up within 30 seconds!" >&2

exit 1
# endregion

