#!/bin/bash

# Start mysql in background
mysqld &

# Wait for mysql to be ready
until mysqladmin ping -h "localhost" --silent; do
  echo "En attente de MySQL..."
  sleep 2
done

# Run sql script
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" test < /scripts/fixture.sql

# Create replication user
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
  CREATE USER 'user_replica'@'%' IDENTIFIED WITH 'caching_sha2_password' BY 'user_replica_password';
  GRANT REPLICATION SLAVE ON *.* TO 'replica'@'%';
  FLUSH PRIVILEGES;
"

# Wait for mysql process to complete
wait
