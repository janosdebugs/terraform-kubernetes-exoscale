#!/bin/bash

set -e

cd /tmp

wget -q --show-progress --https-only --timestamping \
  "https://github.com/exoscale/cli/releases/download/v${exocli_version}/exoscale-cli_${exocli_version}_linux_amd64.tar.gz"

tar -xzf exoscale-cli_${exocli_version}_linux_amd64.tar.gz
chmod +x exo
sudo mv exo /usr/local/bin

mkdir -p ~/.config/exoscale
cat <<EOF >~/.config/exoscale/exoscale.toml
defaultaccount = "network-deployment"

[[accounts]]
  account = "network-deployment"
  defaultTemplate = "Linux Ubuntu 18.04 LTS 64-bit"
  defaultZone = "${exoscale_zone}"
  endpoint = "https://api.exoscale.ch/v1"
  key = "${exoscale_key}"
  name = "network-deployment"
  secret = "${exoscale_secret}"
EOF

set +e

exo privnet associate ${network_id} ${instance_id}
RESULT=$?

set -e
rm ~/.config/exoscale/exoscale.toml

exit $RESULT