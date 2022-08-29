#!/bin/bash

ansible-playbook playbooks/deploy.yaml
ansible-playbook playbooks/isogen.yaml
ansible-playbook playbooks/SO_hard_install.yaml
ansible-playbook playbooks/SO_Manager_Search_Deploy.yaml
ansible-playbook playbooks/SO_MGR_Config.yaml
ansible-playbook playbooks/SO_MGR_setup.yaml
ansible-playbook playbooks/SO_Search_config.yaml
ansible-playbook playbooks/SO_Search_setup.yaml
ansible-playbook playbooks/SO_Sensor_config.yaml
ansible-playbook playbooks/SO_Sensor_setup.yaml
ansible-playbook playbooks/SO_ruleupdate_MGR.yaml 




