#!/bin/bash

# Vérifier que le fichier de configuration existe
if [ -f /etc/mysql/conf.d/slave.cnf ]; then
  echo "Fixing permissions for slave.cnf..."
  chmod 644 /etc/mysql/conf.d/slave.cnf  # Donne des permissions de lecture et écriture pour le propriétaire et de lecture pour les autres
  chown mysql:mysql /etc/mysql/conf.d/slave.cnf  # Changer le propriétaire à mysql
  echo "Permissions for slave.cnf updated successfully."
else
  echo "slave.cnf not found, skipping permission fix."
fi
