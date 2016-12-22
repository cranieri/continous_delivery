#!/bin/bash

##Create infrastructure and inventory file
echo "Creating infrastructure"
terraform apply

##Run Ansible playbooks
echo "Quick sleep while instances spin up"
sleep 20
echo "Ansible provisioning"
ansible-playbook ../ansible/playbooks/main.yml -i ../ansible/playbooks/inventory-ansible -vvv
