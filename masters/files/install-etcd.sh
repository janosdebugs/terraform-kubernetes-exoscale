#!/bin/bash

set -e

cd /tmp
INTERNAL_IP="${privnet_ip}"
ETCD_NAME=$(hostname -s)
ETCDCTL_API=3

# region Download
if [ ! -f etcd-v${etcd_version}-linux-amd64.tar.gz ]; then
  wget -q --show-progress --https-only --timestamping \
    "https://github.com/etcd-io/etcd/releases/download/v${etcd_version}/etcd-v${etcd_version}-linux-amd64.tar.gz"
fi
tar -xf etcd-v${etcd_version}-linux-amd64.tar.gz
sudo mv etcd-v${etcd_version}-linux-amd64/etcd* /usr/local/bin/
sudo mkdir -p /etc/etcd /var/lib/etcd
# endregion

# region Certificates
cat <<EOF | sudo tee /etc/etcd/ca.pem
${ca_cert}
EOF

cat <<EOF | sudo tee /etc/etcd/kubernetes.pem
${kubernetes_cert}
EOF

cat <<EOF | sudo tee /etc/etcd/kubernetes-key.pem
${kubernetes_key}
EOF
# endregion

# region remove old service
if [ -f /etc/systemd/system/etcd.service ]; then
  sudo systemctl stop etcd
  sudo systemctl disable etcd
  sudo rm /etc/systemd/system/etcd.service
  sudo rm -rf /var/lib/etcd/*
  sudo systemctl daemon-reload
fi
# endregion

# region try querying other cluster members and remove nodes
INITIAL_CLUSTER_STATE=new
echo "10.0.0.1" >endpoints
echo "10.0.0.2" >>endpoints
echo "10.0.0.3" >>endpoints
for endpoint in $(cat endpoints | grep -v $${INTERNAL_IP}); do
  set +e
  EXISTING_MEMBER_ID=$(etcdctl member list --endpoints=https://$${endpoint}:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem | grep $${ETCD_NAME} | awk ' { print $1 } ' | sed -e 's/,//')
  if [ $? -eq 0 -a "$${INITIAL_CLUSTER_STATE}" = "new" -a -n $${EXISTING_MEMBER_ID} ]; then
    etcdctl member remove $${EXISTING_MEMBER_ID} --endpoints=https://$${endpoint}:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem
    etcdctl member add $${ETCD_NAME} --peer-urls=https://$${INTERNAL_IP}:2380 --endpoints=https://$${endpoint}:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem
    INITIAL_CLUSTER_STATE=existing
  fi
  set -e
done
# endregion

# region init file
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name $${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://$${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://$${INTERNAL_IP}:2380 \\
  --listen-client-urls https://$${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://$${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${etcd_initial_cluster} \\
  --initial-cluster-state $${INITIAL_CLUSTER_STATE} \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
# endregion

# region wait for etcd to come up
set +e
systemctl is-active --quiet etcd
if [ $? -ne 0 ]; then
  echo "The etcd service is not active" >&2
  exit 1
fi
set -e

for i in $(seq 1 30); do
  set +e
  ETCD_MEMBERS=$(etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem | grep started | wc -l)
  if [ $${ETCD_MEMBERS} -eq 3 ]; then
    echo "etcd is up and running."
    exit 0
  fi
  set -e
  sleep 1
done
echo "etcd failed to come up within 30 seconds!" >&2
exit 1
# endregion