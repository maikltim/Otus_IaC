#!/bin/bash
#зададим ansible.cfg
export ANSIBLE_CONFIG=./ansible/ansible-dyn.cfg
#получим Id mysql кластера, флаг -r означает, что значение без кавычек
MYSQLID=$(terraform output -json | jq -r '.mysql_cluster_id.value')
# выгрузим значение переменной в main.yml для роли wordpress
sed -i "s/-.*.rw.mdb.yandexcloud.net/-$MYSQLID.rw.mdb.yandexcloud.net/" ./ansible/roles/wordpress/vars/main.yml
#запустим ansible playbook для создания инфраструктуры
ansible-playbook ./ansible/playbooks/install.yml