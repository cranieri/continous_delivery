#!/bin/bash

##Create infrastructure and inventory file
echo "Creating infrastructure"
terraform apply

##Run Ansible playbooks
echo "Quick sleep while instances spin up"
sleep 20
echo "Ansible provisioning"
ansible-playbook /Users/cosimoranieri/src/ansible-for-devops/deployments/playbooks/main.yml -i /Users/cosimoranieri/src/ansible-for-devops/deployments/playbooks/inventory-ansible -vvv
