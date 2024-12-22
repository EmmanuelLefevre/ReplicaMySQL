#!/bin/bash

# Attendre que MySQL soit complètement démarré
until mysqladmin ping -h "localhost" --silent; do
    echo "Waiting for MySQL to be ready..."
    sleep 5
done

# Attendre un peu plus longtemps pour s'assurer que le master est prêt
echo "Waiting a few more seconds before configuring replication..."
sleep 15

# Configurer la réplication avec le master
echo "Master MySQL ready. Setting up replication..."
MASTER_STATUS=$(mysql -h "$MYSQL_REPLICATION_MASTER_HOST" -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW MASTER STATUS;" | grep -v "File" | awk '{print $1, $2}')
MASTER_LOG_FILE=$(echo $MASTER_STATUS | cut -d ' ' -f 1)
MASTER_LOG_POS=$(echo $MASTER_STATUS | cut -d ' ' -f 2)

mysql -h "$1" -u root -proot_password -e "
  CHANGE MASTER TO
    MASTER_HOST='$MYSQL_REPLICATION_MASTER_HOST',
    MASTER_USER='replica',
    MASTER_PASSWORD='$MYSQL_REPLICATION_PASSWORD',
    MASTER_LOG_FILE='$MASTER_LOG_FILE',
    MASTER_LOG_POS=$MASTER_LOG_POS;
  START SLAVE; "

echo "Replication set up successfully."
