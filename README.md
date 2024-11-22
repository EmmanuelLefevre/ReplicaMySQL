# REPLICA BDD MLASTER SLAVE

## SOMMAIRE
- [INTRODUCTION](#introduction)
- [CREATION DES FICHIERS DE CONFIGURATION MYSQL](#creation-des-fichiers-de-configuration-mysql)
  - [Master](#master)
  - [Slave](#slave)
- [SCRIPT SQL](#script-sql)
- [CREATION DE L'IMAGE](#creation-de-limage)
- [CREATION DES CONTAINERS](#creation-des-containers)
- [COPIER FICHIER SQL DANS LE CONTAINER MASTER](#copier-fichier-sql-dans-le-container-master)
- [CONFIGURER REPLICATION MASTER / SLAVE](#configurer-replication-masterslave)
- [CREER SAUVEGARDE SUR LE CONTAINER SLAVE](#creer-sauvegarde-sur-le-container-slave)
- [VERIFICATION REPLICATION](#verification-replication)
- [SUPPRESSION IMAGE EN STATUT DANGLING](#suppression-image-en-statut-dangling)
- [LOGS CONTAINER](#logs-container)
- [RECHARGER LA BASE DE SAUVEGARDE SUR LE CONTENEUR MASTER EN CAS DE CRASH](#recharger-la-base-de-sauvegarde-sur-le-conteneur-master-en-cas-de-crash)
- [REINITIALISER TOUTE LA CONFIGURATION](#reinitialiser-toute-la-configuration)

## INTRODUCTION
Ce projet configure un environnement Docker multi-conteneurs pour déployer une architecture MySQL Master-Slave en utilisant MySQL 8.0 sur Ubuntu 22.04, avec des scripts personnalisés et des fichiers de configuration spécifiques.

## CREATION DES FICHIERS DE CONFIGURATION MYSQL
### Master
Créer un fichier **master.cnf** dans un dossier **configs**
```conf
[mysqld]
# Must be different from the slave server.
server-id=1

# Binary log to record changes made to databases.
log-bin=master_bin
# Sets number days before binlog files will automatically deleted.
binlog_expire_logs_days=99
# Set maximum size of binlog files before new file will created.
max_binlog_size=100M

# Specify the databases whose events should be included in the binary transaction log file.
binlog-do-db=test

# Set authentication plugin
default-authentication-plugin=caching_sha2_password
```
### Slave
Créer un fichier **slave.cnf** dans un dossier **configs**
```conf
[mysqld]
# Must be different from the master server.
server-id=2

# Binary log to record databases changes.
log-bin=slave_bin
# Sets number days before binlog files will automatically deleted.
binlog_expire_logs_days=99
# Set maximum size of binlog files before new file will created.
max_binlog_size=100M

# Specify databases whose events should be included in binary transaction log file.
binlog-do-db=test

# Specify file name in which slave server will store events received from master server.
relay-log=slave_relay_bin

# By default, changes applied by slave server aren't recorded in its own binary log (binlog).
# This could a problem if slave server also has to serve as a master server for other slaves.
log_replica_updates=1

# Prohibit data modification requests.
# Slave server musn't modify its own data, but only read it and apply changes received from master server.
read-only=1

# Set authentication plugin
default-authentication-plugin=caching_sha2_password


########## Parameters for master server connection ##########
# Set address or hostname of master server.
master-host=mysql_master

# Set created replica username to connect master server.
master-user=user_replica

# Set created replica user password to connect master server.
master-password=user_replica_password

# Set port on which master server listens for replication connections.
master-port=3306

# Limit replication to the specified database.
replicate-do-db=test
```

## SCRIPT SQL
Créer un fichier **fixture.sql** dans un dossier **scripts**
```sql
SET NAMES 'utf8';
SET CHARACTER SET utf8;
SET SESSION collation_connection = 'utf8_general_ci';

CREATE TABLE IF NOT EXISTS test (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(255) NOT NULL,
    prenom VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO test (nom, prenom)
VALUES
('Lefevre', 'Emmanuel'),
('Adulyadej', 'Bhumibol'),
('Poutine', 'Vladimir'),
('Zelensky', 'Volodymyr');
```

## CREATION DE L'IMAGE
### Créer un fichier Dockerfile
```dockerfile
# Use official UBUNTU 22.04 image as a base
FROM ubuntu:22.04

# Set environment variable to avoid debconf errors
ENV DEBIAN_FRONTEND=noninteractive

#####==========Install dependencies and MySQL 8.0==========#####
RUN apt-get update && apt-get install -y \
  wget \
  lsb-release \
  gnupg \
  net-tools \
  passwd \
  && wget https://dev.mysql.com/get/mysql-apt-config_0.8.17-1_all.deb \
  && echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | debconf-set-selections \
  && dpkg -i mysql-apt-config_0.8.17-1_all.deb \
  && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B7B3B788A8D3785C \
  && apt-get update && apt-get install -y mysql-server=8.0.* \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Check mysql installed version
RUN mysqld --version


#####==========Create mysql user and group==========#####
# Create a mysql user and group (non-root) to run mysql securely
RUN groupadd -r mysql || true \
  && useradd -r -g mysql -m -d /var/lib/mysql mysql || true


#####==========Set build argument and environment variable for configuration file==========#####
ARG ROLE
ENV ROLE=${ROLE}


#####==========Copy custom configuration files==========#####
# Copy configuration file depending on ROLE value
COPY ./configs/${ROLE}.cnf /etc/mysql/conf.d/${ROLE}.cnf

# Copy other necessary scripts
COPY ./scripts/fixture.sql /scripts/fixture.sql
COPY ./scripts/docker-entrypoint.sh /scripts/docker-entrypoint.sh


#####==========Give necessary permissions to scripts and render them executable==========#####
RUN chmod 644 /etc/mysql/conf.d/${ROLE}.cnf
RUN chmod +x /scripts/docker-entrypoint.sh
RUN chown -R mysql:mysql /var/lib/mysql


#####==========wait_for_mysql.sh==========#####
# Copy script into containers
COPY ./scripts/wait_for_mysql.sh /usr/local/bin/wait_for_mysql.sh
# Check if file is nicely copied
RUN ls -l /usr/local/bin/wait_for_mysql.sh
# Give necessary permissions to script and render it executable
RUN chmod +x /usr/local/bin/wait_for_mysql.sh


#####==========Set default command to start mysql server==========#####
# Use non-root mysql user to run the server
USER mysql

# Display MySQL version on container start and keep container running
CMD echo "MySQL version:" && mysqld --version && tail -f /dev/null
```

## CREATION DES CONTAINERS
### Créer un fichier docker-compose.yml
```yml
version: '3.8'

networks:
  mysql_network:
    driver: bridge

services:
  master:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        ROLE: master
    image: ubuntu_mysql8.0_replica:22.04
    container_name: mysql_master
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: test
      MYSQL_USER: replica_master
      MYSQL_PASSWORD: replica_master_password
    ports:
      - "3307:3306"
    networks:
      - mysql_network
    volumes:
      - ./master_data:/var/lib/mysql
      - ./scripts/fixture.sql:/scripts/fixture.sql
      - ./scripts/docker-entrypoint.sh:/scripts/docker-entrypoint.sh
    entrypoint: ["/bin/bash", "/scripts/docker-entrypoint.sh"]
    command: ["mysqld", "--user=mysql"]

  slave:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        ROLE: slave
    image: ubuntu_mysql8.0_replica:22.04
    container_name: mysql_slave
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: test
      MYSQL_USER: replica_slave
      MYSQL_PASSWORD: replica_slave_password
    entrypoint:
      - /usr/local/bin/wait_for_mysql.sh
      - "mysql_master"
    depends_on:
      - master
    ports:
      - "3308:3306"
    networks:
      - mysql_network
    volumes:
      - ./slave_data:/var/lib/mysql
    command: ["mysqld", "--user=mysql"]

volumes:
  master_data:
  slave_data:
```
### Créez l'image

### Construire l'image
```shell
docker-compose build --no-cache
```
### Lancer les containers dans Docker desktop
```shell
docker-compose up -d
```
### Vérification
```shell
docker ps
```

## COPIER FICHIER SQL DANS LE CONTAINER MASTER
Powershell
```shell
docker cp C:/Users/Darka/Desktop/Projets/tp_quentin_chartrin/fixture.sql mysql_master:/fixture.sql
```
### Vérification
```shell
docker exec -it mysql_master ls /
```
### Charger le script dans la base de données du container master
Ouverture shell mysql
```shell
docker exec -it mysql_master mysql -uroot -proot_password
```
```sql
SHOW DATABASES;
USE test;
SOURCE /fixture.sql;
SELECT * FROM test;
EXIT;
```

## CONFIGURER REPLICATION MASTER / SLAVE
### Container master
Attribuer droit
```shell
chmod -R 755 /path/to/slave_data
chown -R mysql:mysql /path/to/slave_data
```
Ouverture shell mysql container master
```shell
docker exec -it mysql_master mysql -uroot -proot_password
```
Créer un utilisateur "replica" dédié à la réplication avec **caching_sha2_password**
```sql
CREATE USER 'replica'@'%' IDENTIFIED WITH 'caching_sha2_password' BY 'replica_password';
GRANT REPLICATION SLAVE ON *.* TO 'replica'@'%';
FLUSH PRIVILEGES;
SELECT User, Host, plugin FROM mysql.user WHERE User = 'replica';
SHOW MASTER STATUS;
EXIT;
```
Si l'utilisateur "replica" existe déjà, changer le mot de passe
```sql
ALTER USER 'replica'@'%' IDENTIFIED WITH 'caching_sha2_password' BY 'nouveau_mot_de_passe';
FLUH PRIVILEGES;
```

⚠️ Prendre note des valeurs **File** et **Position**  

### Container slave
Ouverture shell mysql container slave
```shell
docker exec -it mysql_slave mysql -uroot -proot_password
```
Configurer la réplication
```shell
CHANGE MASTER TO
  MASTER_HOST='mysql_master',
  MASTER_USER='replica',
  MASTER_PASSWORD='replica_password',
  MASTER_LOG_FILE='<FILE_VALUE>',
  MASTER_LOG_POS=<POSITION_VALUE>;
```
```shell
CHANGE MASTER TO
  MASTER_HOST='mysql_master',
  MASTER_USER='replica',
  MASTER_PASSWORD='replica_password',
  MASTER_LOG_FILE=' mysql-bin.000003',
  MASTER_LOG_POS=1556;
```
Démarrer la réplication  
**MySQL 8.0.22+**
```shell
START REPLICA;
SHOW REPLICA STATUS\G
exit;
```
**MySQL 5.7 ou versions antérieures**
```shell
START SLAVE;
SHOW SLAVE STATUS\G
exit;
```

Vérifiez que **Slave_IO_Running** et **Slave_SQL_Running** ont la valeur "Yes".

## CREER SAUVEGARDE SUR LE CONTAINER SLAVE
```shell
docker exec mysql_slave sh -c 'exec mysqldump -uroot -proot_password test > /var/lib/mysql/sauvegarde.sql'
```
```shell
docker exec -it mysql_slave ls /var/lib/mysql
```
## OU CREER SAUVEGARDE SUR L'HOTE
1. Exécuter le dump dans le conteneur
```shell
docker exec mysql_slave sh -c 'exec mysqldump -uroot -proot_password test > /tmp/sauvegarde.sql'
```
2. Copier le fichier du conteneur vers l'hôte
```shell
docker cp mysql_slave:/tmp/sauvegarde.sql C:/Users/Darka/Desktop/Projets/tp_quentin_chartrin/sauvegarde.sql
```

## VERIFICATION REPLICATION
Modifiez une donnée dans le **master** et vérifiez sa synchronisation dans le **slave**.
1. Dans le master
```shell
docker exec -it mysql_master mysql -uroot -proot_password
```
```sql
USE test;
INSERT INTO test (nom, prenom) VALUES ('Trump', 'Donald');
SELECT * FROM test;
EXIT;
```
2. Dans le slave
```shell
docker exec -it mysql_slave mysql -uroot -proot_password
```
```sql
USE test;
SELECT * FROM test;
EXIT;
```

## SUPPRESSION IMAGE EN STATUT DANGLING
```shell
docker rmi $(docker images -f "dangling=true" -q)
```
## LOGS CONTAINER
```shell
docker logs mysql_master
```
```shell
docker logs mysql_slave
```

## RECHARGER LA BASE DE SAUVEGARDE SUR LE CONTENEUR MASTER EN CAS DE CRASH
1. Stopper la réplication
```shell
STOP SLAVE;
RESET SLAVE ALL;
```

## REINITIALISER TOUTE LA CONFIGURATION
```shell
docker stop mysql_master mysql_slave
docker rm mysql_master mysql_slave
docker rmi ubuntu_mysql8.0_replica:22.04
docker network rm mysql_network
docker rmi $(docker images -f "dangling=true" -q)
docker builder prune --all --force
Remove-Item -Recurse -Force .\master_data, .\slave_data
Remove-Item .\sauvegarde.sql
```

***

⭐⭐⭐ I hope you enjoy it, if so don't hesitate to leave a like on this repository and on the "Settings" one (click on the "Star" button at the top right of the repository page). Thanks 🤗
