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

# region Reboot
reboot --reboot
# endregion