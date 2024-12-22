#!/bin/bash

# Vérifier que le fichier de configuration existe
if [ -f /etc/mysql/conf.d/master.cnf ]; then
  echo "Fixing permissions for master.cnf..."
  chmod 644 /etc/mysql/conf.d/master.cnf  # Donne des permissions de lecture et écriture pour le propriétaire et de lecture pour les autres
  chown mysql:mysql /etc/mysql/conf.d/master.cnf  # Changer le propriétaire à mysql
  echo "Permissions for master.cnf updated successfully."
else
  echo "master.cnf not found, skipping permission fix."
fi
