# Install Kubernetes on Exoscale

> **Warning!** This code is an experiment and is not designed to be production grade! Use at your own peril!

This terraform repository loosely emulates
[Kelsey Hightowers "Kubernetes the hard way"](https://github.com/kelseyhightower/kubernetes-the-hard-way) on Exoscale
with Terraform.

## Usage

You will **have** to install the [wait plugin](https://github.com/janoszen/terraform-provider-wait) so that Terraform
can wait for the Kubernetes API to become available before deploying CoreDNS, etc.

You will also have to have a domain name that has its DNS hosted on Exoscale so DNS records can be created.

You can then create a `terraform.tfvars` file with the following content:

```
exoscale_key = "EXO..."
exoscale_secret = "..."
exoscale_zone = "at-vie-1"
firewall_allowed_k8s = [
  "your-ip-here/32"
]
firewall_allowed_ssh = [
  "your-ip-here/32"
]
service_domain = "k8s.your-domain.com"
service_domain_zone = "your-domain.com"
server_admin_users = {
  "your-user": "ssh-rsa ..."
}
workers = 1
```

You can then run `terraform init` and `terraform apply` and you will hopefully get a running Kubernetes cluster and
your admin credentials in the `config` directory.

## Inner workings

### Certificates

Terraform has the ability to create certificate authorities. This is used to create a CA for Kubernetes which is used
to sign certificates for all components.

### Master nodes

First of all 3 master nodes are created and they are attached to a private network. The private network is needed
so that etcd can have predictable IP addresses.

Once these nodes come up etcd is installed and configured to communicate across the private network. Subsequentially
the Kubernetes components (api server, controller-manager, scheduler) are installed as systemd services. Finally
an nginx is configured to serve a status check page.

After that a managed elastic IP is deployed that checks the status page served by nginx. This elastic IP becomes the
URL for Kubernetes that workers and clients use.

### Workers

Once the masters are deployed the workers can be provisioned. At this time workers are started explicitly and not via 
an instance pool. They get the kubelet and kube-proxy installed and configured via systemd once they boot up.

### Kubernetes components

Once the workers are running several things are deployed into Kubernetes itself. The installation scripts have been
transformed to Terraform code so they can be properly managed. These components are:

- CoreDNS
- Cannel (planned)
- MetalLB (planned)
- nginx ingress controller (planned)
- helm

## Security notes

- The metadata server does not represent a security threat because no secrets are provisioned in the user-data. However,
  this means that any scaling action has to be done using Terraform.
- Currently there are no updates possible to the masters because the etcd data directories would need to be preserved
  which is not implemented at this time.
- The terraform state file contains sensitive secrets and should be handled with care.
- At this time the certificates are output into the log, this needs to change later.
- At this time an Exoscale API key and secret is passed to the master nodes during installation to attach the private
  network. This is due to the fact that the Exoscale provider [doesn't support attaching private networks at
  installation time](https://github.com/terraform-providers/terraform-provider-exoscale/issues/48). These secrets
  are removed after the installation.
- Because cloud installations work SSH key checking is not done by Terraform. The workaround for that would be
  to put the SSH host keys in the userdata, shifting the trust from the local network provider to Exoscale. This would
  also mean that the metadata server would need to be restricted using a network policy in Kubernetes.

## Stability notes

- At this time there are no backups of etcd.
- When a master node dies it has to be manually removed from the etcd cluster in order for it to be reprovisioned.
- Exoscale does not have block storage so only local volumes can be used.
