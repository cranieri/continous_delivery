#!/bin/bash

##Create infrastructure and inventory file
# echo "Creating infrastructure"
# sudo rm -rf .terraform/
# sudo terraform get -update
# sudo terraform apply

##Run Ansible playbooks
echo "Ansible provisioning"
ansible-playbook ../ansible/playbooks/main.yml --extra-vars "cc_hosts=tag_Name_dummyapp_prod_001,tag_Name_dummyapp_prod_002 app_version=$1 ansible_ssh_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa_dummy"
