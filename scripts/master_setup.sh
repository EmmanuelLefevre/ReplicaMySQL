#!/bin/bash

# Wait for mysql to be ready
until mysqladmin ping -h "localhost" --silent; do
  echo "Waiting for MySQL to be ready..."
  sleep 5
done

# Créer l'utilisateur de réplication
echo "Creating replication user..."
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
  CREATE USER IF NOT EXISTS 'replica'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_REPLICATION_PASSWORD';
  GRANT REPLICATION SLAVE ON *.* TO 'replica'@'%';
  FLUSH PRIVILEGES; "
echo "Replication user created and privileges granted."

# Changer le plugin d'authentification de root
echo "Changing root authentication plugin to mysql_native_password..."
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
  ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
  FLUSH PRIVILEGES; "

# Run sql script
echo "Running fixture script to initialize database..."
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" $MYSQL_DATABASE < /scripts/fixture.sql
echo "Database initialized with fixture data."

# Afficher l'état du master (utile pour récupérer le fichier binaire et la position)
echo "Displaying master status..."
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW MASTER STATUS;"
