#!/bin/bash

##Create infrastructure and inventory file
echo "Creating infrastructure"
sudo rm -rf .terraform/
sudo terraform get -update
sudo terraform apply

##Run Ansible playbooks
echo "Quick sleep while instances spin up"
sleep 20
echo "Ansible provisioning"
ansible-playbook ../ansible/playbooks/main.yml -i ../ansible/playbooks/inventory-ansible -vvv
