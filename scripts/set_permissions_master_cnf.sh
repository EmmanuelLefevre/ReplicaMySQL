#!/bin/bash

if [ -f /etc/mysql/conf.d/master.cnf ]; then
  echo "Fixing permissions for master.cnf..."
  chmod 644 /etc/mysql/conf.d/master.cnf
  chown mysql:mysql /etc/mysql/conf.d/master.cnf
  echo "Permissions for master.cnf updated successfully."
else
  echo "master.cnf not found, skipping permission fix."
fi
