#!/usr/bin/env bash
# Installation de Kolla-Ansible 2025.2 et déploiement All-in-One
# À lancer sur Ubuntu Server 24.04, en tant qu'utilisateur sudoer (pas root)
set -euo pipefail

# 1. Dépendances système et environnement virtuel Python
sudo apt update
sudo apt install -y git python3-dev libffi-dev gcc libssl-dev libdbus-glib-1-dev \
  python3-venv pkg-config libdbus-1-dev libglib2.0-dev
python3 -m venv ~/kolla-venv
source ~/kolla-venv/bin/activate
pip install -U pip

# 2. Kolla-Ansible (branche stable 2025.2) + SDK nécessaires aux prechecks
pip install git+https://opendev.org/openstack/kolla-ansible@stable/2025.2
pip install docker dbus-python

# 3. Fichiers de configuration, inventaire, collections Ansible, mots de passe
sudo mkdir -p /etc/kolla/globals.d
sudo chown -R "$USER:$USER" /etc/kolla
cp -r ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/all-in-one ~/
cp "$(dirname "$0")/../config/globals.d/00-aio.yml" /etc/kolla/globals.d/
kolla-ansible install-deps
kolla-genpwd   # génère /etc/kolla/passwords.yml (NE JAMAIS PUBLIER)

# 4. Déploiement
kolla-ansible bootstrap-servers -i ~/all-in-one
kolla-ansible prechecks -i ~/all-in-one
kolla-ansible deploy -i ~/all-in-one
kolla-ansible post-deploy -i ~/all-in-one

# 5. Client OpenStack
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/2025.2
