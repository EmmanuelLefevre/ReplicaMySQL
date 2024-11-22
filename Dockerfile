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

# CMD is set to start MySQL with the proper user
# CMD ["mysqld", "--user=mysql"]
