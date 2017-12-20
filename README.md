# codedx-docker

This repository contains the scripts necessary to create docker images (and from these images, docker containers) that comprise a fully functional [Code Dx](https://www.codedx.com) installation.
A docker based installation of Code Dx contains 2 parts: the database image, based off of MariaDB, and the Tomcat image that hosts the Code Dx web application. The Tomcat docker container will be networked with the MariaDB container to allow Code Dx to store data.

There are two sections in this README: Quick Installation and Manual Installation. Quick installation uses `docker-compose` to stand up a functional instance of Code Dx automatically, building the Tomcat/Code Dx image automatically if required and starting a properly configured MariaDB container. Manual Installation details instructions for manually building the Tomcat/Code Dx image, creating and starting a container from that image, and starting a MariaDB container with the proper arguments.

All of the following instructions expect `codedx.war`, obtainable from a distribution of Code Dx, to be placed in the following directory (relative to the root of the repository): `codedx-docker/codedx-tomcat/`.

## Providing the Docker Image with a Code Dx License
In order to automatically provide the Tomcat/Code Dx docker image with a valid Code Dx license, paste a valid license string into `codedx-docker/codedx-tomcat/license.lic`, and build the image using the instructions in the following sections. Tomcat/Code Dx containers created from this image will automatically use the license. If the license file is left empty, Code Dx will use an evaluation license.

## Quick Installation

### Overview
This section details how to start up a functional instance of Code Dx using docker, accessible via port 8080.

### Instructions
1. Install docker using **[these instructions](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-docker-ce-1)**.
2. Install **[docker-compose](https://docs.docker.com/compose/install/)**.
3. If desired, edit the following values in the `docker-compose.yml` file.
- The following configuration values affect the database container:
  - MYSQL_ROOT_PASSWORD: The password for MYSQL's root user.
  - MYSQL_DATABASE: The name of the database to be created automatically when the container is started.
- The following configuration values affect the Tomcat based Code Dx container:
  - DB_URL: The url that Code Dx uses to connect to it's database.
  - DB_DRIVER: The jdbc database driver that Code Dx uses.
  - DB_USER: The database user Code Dx connects with.
  - DB_PASSWORD: The password Code Dx connects with.
  - SUPERUSER_NAME: The root administrator name for Code Dx.
  - SUPERUSER_PASSWORD: The password for the Code Dx root administrator.
  - ports: The list of values underneath this header controls the ports forwarded from the docker instance to the host machine. The left value represents the port bound on the host machine, the right value represents the port bound in the docker container. If there is a port conflict on the host machine, alter the left value.
4. Run `docker-compose up`. Alternatively, run `docker-compose up -d` to detach and run in the background.
5. When the message "The Server is now ready!" appears in the console, navigate to http://localhost:8080/codedx to log into your newly spun up Code Dx instance.
6. To stop, run `docker-compose stop`, and to remove the docker containers automatically created, run `docker-compose down`.

### Quick Updating
To update the docker container's version of Code Dx:
1. Copy the newer `codedx.war` file over `codedx-docker/codedx-tomcat/codedx.war`.
2. Run `docker-compose stop` and then `docker-compose down`. Your data will be preserved in volumes as defined in the docker-compose.yml.
3. Run `docker-compose up --build` to build and run the updated containers.

## Manual Installation

### Overview
This sections contains instructions for manually building and running a docker based installation of Code Dx, useful for development and debugging. The Tomcat/Code Dx image is based on the **[Tomcat](https://hub.docker.com/_/tomcat/)** image hosted on **[Docker Hub](https://hub.docker.com/)**. This section also details the use of **[MariaDB](https://hub.docker.com/_/mariadb/)** in such an installation.

### Build Instructions
These build instructions detail how to build the Tomcat/Code Dx docker image.
1. Install docker using **[these instructions](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-docker-ce-1)**.
2. Unzip the latest `codedx.war` file from a Code Dx distribution into the following folder (relative to the root of the repository): `codedx-docker/codedx-tomcat/`. 
3. Change the working directory to `codedx-docker/codedx-tomact/`, and then as root run the build script: `sudo ./build.sh`
4. An image should be available in your docker installation as well as saved to disk in the `codedx-docker/codedx-tomcat/target/` folder with the name of `codedx.tar`. To verify the image exists in your local docker installation, run `sudo docker images`. To load the image into other docker instances, or after removing the image, use the command: `sudo docker image load --input target/codedx.tar`

### Run Instructions
These run instructions detail how to manually start up a MariaDB container and Tomcat/Code Dx container built from the above instructions. It is expected that docker is already installed.
1. Create a docker network for codedx: `sudo docker network create --driver bridge testnet`
2. Pull the MariaDB docker image into your docker installation: `sudo docker pull mariadb`
3. Create and run a MariaDB container with a root password and a volume, and attach it to the network created above: `docker run --name codedx-db --network testnet -v codedx-db-files:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=codedx -d mariadb --optimizer_search_depth=0 --innodb_flush_log_at_trx_commit=0`. It is important that the database is running before attempting to create and run a Code Dx/Tomcat container. Verify the database is created and started properly with the following command: `sudo docker logs codedx-db`.
4. As root, run the first-run-codedx script: `sudo ./first-run-codedx.sh`. Alternatively, run the following command: `docker run --detach -v codedx-appdata:/opt/codedx --name codedx --network testnet --publish 8080:8080 codedx`. This starts the container, creates a volume named `codedx-appdata` where user data will be stored, and opens port 8080 to the container.
5. To confirm that the Tomcat server hosting codedx started successfully, use the following command: `sudo docker logs codedx | tail`
6. Navigate to http://localhost:8080/codedx, and you should be greeted with the login page.

### Manual Updating
To update the Tomcat/Code Dx container:
1. Copy the newer `codedx.war` file over `codedx-docker/codedx-tomcat/codedx.war`.
2. Stop any current running instances of Tomcat/Code Dx with `sudo docker stop codedx`.
3. Remove the outdated Tomcat/Code Dx container with `sudo docker rm codedx`.
4. Remove the outdated Tomcat/Code Dx image with `sudo docker rmi codedx`. This is optional, building the updated image will simply rename the old image to something else, and give the new updated image the `codedx` label.
5. Build the updated image: `sudo ./build.sh`.
6. Run the first-run-codedx script as showin in step 4 of the Run Instructions: `sudo ./first-run-codedx.sh`.
7. Navigate to http://localhost:8080/codedx, and you will be greeted with the login page of an updated Code Dx installation.

To update the MariaDB container:
1. Stop any current running instances of Tomcat/Code Dx with `sudo docker stop codedx`.
2. Stop any current running instances of MariaDB with `sudo docker stop codedx-db`.
3. Remove the outdated MariaDB container with `sudo docker rm codedx-db`.
4. Pull the latest MariaDB image from docker hub: `docker pull mariadb`.
5. Create and run a MariaDB container as described in step 3 of the Run Instructions: `docker run --name codedx-db --network testnet -v codedx-db-files:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=codedx -d mariadb --optimizer_search_depth=0 --innodb_flush_log_at_trx_commit=0`
6. Start the Tomcat/Code Dx container that was stopped in step 1: `sudo docker start codedx`.

## HTTP Over SSL

This Tomcat container can support HTTP over SSL. For example, generate a self-signed certificate with `openssl` (or better yet, obtain a real certificate from a certificate authority):

```bash
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj \
    "/C=US/ST=Colorado/L=Boulder/O=Unidata/CN=tomcat.example.com" -keyout \
    ./ssl.key -out ./ssl.crt
```

The `server.xml` file available in `codedx-docker/codedx-tomcat/templates/` contains a configuration that supports SSL using **[Tomcat's SSL capability](https://tomcat.apache.org/tomcat-8.0-doc/ssl-howto.html)**.

This template can be mounted over the existing `server.xml` in the docker image. The SSL certificate and private key must also be mounted.

If manually building and running the Tomcat/Code Dx image, the command used in step 4 of the Run Instructions above will be as follows:

```bash
docker run --detach \
	-v codedx-appdata:/opt/codedx \
	-v /path/to/server.xml:/usr/local/tomcat/conf/server.xml \
	-v /path/to/ssl.crt:/usr/local/tomcat/conf/ssl.crt \
	-v /path/to/ssl.key:/usr/local/tomcat/conf/ssl.key \
	--name codedx \
	--network testnet \
	--publish 8443:8443 \
	codedx
```

or if using `docker-compose`, the `docker-compose.yml` codedx-tomcat section will look like:

```yaml
    codedx-tomcat:
        build: ./codedx-tomcat/
        environment:
            - DB_URL=jdbc:mysql://codedx-db/codedx
            - DB_DRIVER=com.mysql.jdbc.Driver
            - DB_USER=root
            - DB_PASSWORD=root
            - SUPERUSER_NAME=admin
            - SUPERUSER_PASSWORD=secret
        volumes:
            - codedx-appdata:/opt/codedx
            - /path/to/ssl.crt:/usr/local/tomcat/conf/ssl.crt
            - /path/to/ssl.key:/usr/local/tomcat/conf/ssl.key
            - /path/to/server.xml:/usr/local/tomcat/conf/server.xml
        ports:
            - 8443:8443
        depends_on:
            - codedx-db
```

After following following the rest of each method's respective setup instructions, Code Dx should now be available over https at the following url: https://localhost:8443/codedx
