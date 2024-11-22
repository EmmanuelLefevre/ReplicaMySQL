# REPLICA BDD MLASTER SLAVE

## SOMMAIRE
- [INTRODUCTION](#introduction)
- [CREATION  DES CONTAINERS](#creation-des-containers)
- [SCRIPT SQL](#script-sql)
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

## CREATION  DES CONTAINERS
### Créez un fichier docker-compose.yml
```yml
version: '3.8'

services:
  master:
    image: mysql:8.0
    container_name: mysql_master
    ports:
      - "3307:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: test
      MYSQL_USER: replicator
      MYSQL_PASSWORD: replicator_password
    volumes:
      - ./master_data:/var/lib/mysql
    command: >
      --server-id=1
      --log-bin=mysql-bin
      --binlog-format=ROW
      --authentication_policy=caching_sha2_password

  slave:
    image: mysql:8.0
    container_name: mysql_slave
    ports:
      - "3308:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: test
      MYSQL_USER: replicator
      MYSQL_PASSWORD: replicator_password
    volumes:
      - ./slave_data:/var/lib/mysql
    command: >
      --server-id=2
      --relay-log=relay-log
      --read-only=1
      --authentication_policy=caching_sha2_password
      --master-host=mysql_master
      --master-user=replicator
      --master-password=replicator_password
      --master-port=3306
      --replicate-do-db=test
```
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

## SCRIPT SQL
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
