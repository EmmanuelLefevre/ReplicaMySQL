#!/bin/bash

if [ -f /etc/mysql/conf.d/slave.cnf ]; then
  echo "Fixing permissions for slave.cnf..."
  chmod 644 /etc/mysql/conf.d/slave.cnf
  chown mysql:mysql /etc/mysql/conf.d/slave.cnf
  echo "Permissions for slave.cnf updated successfully."
else
  echo "slave.cnf not found, skipping permission fix."
fi
