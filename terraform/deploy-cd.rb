#!/bin/bash

##Create infrastructure and inventory file
# echo "Creating infrastructure"
# sudo rm -rf .terraform/
# sudo terraform get -update
# sudo terraform apply

##Run Ansible playbooks
echo "Ansible provisioning"
ansible-playbook ../ansible/playbooks/main-cd.yml --extra-vars "ansible_ssh_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa_dummy"
