#!/bin/bash

########## Check script to ensure MySQL is ready before starting replication on slave host ##########

# host name (container mysql_master) is passed as an argument
host=$1
shift

# Loop to check if mysql is ready to receive connections
until mysql -h "$host" -u root -p"$MYSQL_ROOT_PASSWORD" -e 'show databases'; do
  echo "Waiting for MySQL at $host to be ready..."
  sleep 2
done

# Running command after mysql is ready on master server
exec "$@"
