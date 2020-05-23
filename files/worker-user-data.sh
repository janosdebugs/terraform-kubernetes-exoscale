#!/bin/bash

#region Users
function create_user() {
  useradd -m -s /bin/bash $1
  mkdir -p /home/$1/.ssh
  echo "$2" >/home/$1/.ssh/authorized_keys
  chown -R $1:$1 /home/$1
  gpasswd -a $1 sudo
  gpasswd -a $1 adm
}

sed -i -e 's/%sudo\s*ALL=(ALL:ALL)\s*ALL/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/' /etc/sudoers
%{ for user,ssh_key in users }
create_user ${user} "${ssh_key}"
%{ endfor }
#endregion

# region Updates
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confnew" --force-yes -fuy upgrade
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confnew" --force-yes -fuy dist-upgrade
DEBIAN_FRONTEND=noninteractive apt-get install -y rsync htop tcpdump tcpflow unzip mc
# endregion

# region SSH
sed -i -e 's/#Port 22/Port ${ssh_port}/' /etc/ssh/sshd_config
# endregion

# region Network
IP=$(ifconfig eth0 | grep inet | grep -v inet6 | awk ' { print $2 } ')
cat <<EOF >/etc/hosts
$${IP} ${name}.${domain} ${name}
127.0.0.1 localhost

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF
cat <<EOF >/etc/systemd/resolved.conf
[Resolve]
#DNS=
#FallbackDNS=
Domains=${domain}
#LLMNR=no
#MulticastDNS=no
#DNSSEC=no
#Cache=yes
#DNSStubListener=yes
EOF
# endregion

# region Reboot
reboot --reboot
# endregion