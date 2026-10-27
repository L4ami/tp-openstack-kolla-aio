#!/usr/bin/env bash
# Validation : image, gabarit, réseaux, routeur, sécurité, clé, instance, IP flottante
# Prérequis : source ~/kolla-venv/bin/activate && source /etc/kolla/admin-openrc.sh
set -euo pipefail

# Image Cirros
wget -nc https://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img
openstack image create --disk-format qcow2 --container-format bare --public \
  --file cirros-0.6.3-x86_64-disk.img cirros

# Gabarit
openstack flavor create --vcpus 1 --ram 256 --disk 1 m1.tiny

# Réseau externe (VMnet8) et réseau privé
openstack network create --external --provider-network-type flat \
  --provider-physical-network physnet1 public
openstack subnet create --network public --subnet-range 192.168.190.0/24 \
  --gateway 192.168.190.2 --allocation-pool start=192.168.190.100,end=192.168.190.120 \
  --no-dhcp public-subnet
openstack network create private
openstack subnet create --network private --subnet-range 10.10.10.0/24 \
  --gateway 10.10.10.1 --dns-nameserver 192.168.190.2 private-subnet

# Routeur
openstack router create router1
openstack router set --external-gateway public router1
openstack router add subnet router1 private-subnet

# Groupe de sécurité : ping + SSH
openstack security group create ssh-icmp --description "Autorise ping et SSH"
openstack security group rule create --protocol icmp ssh-icmp
openstack security group rule create --protocol tcp --dst-port 22 ssh-icmp

# Paire de clés (la clé privée reste en local, jamais publiée)
[ -f ~/.ssh/openstack_key ] || ssh-keygen -t ed25519 -N "" -f ~/.ssh/openstack_key
openstack keypair create --public-key ~/.ssh/openstack_key.pub cle-lami

# Instance + IP flottante
openstack server create --image cirros --flavor m1.tiny --network private \
  --security-group ssh-icmp --key-name cle-lami --wait vm-cirros
FIP=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip vm-cirros "$FIP"
openstack server list
echo "Connexion : ssh -i ~/.ssh/openstack_key cirros@$FIP"
