# codedx-docker

This repository contains the scripts necessary to create docker images that comprise a fully functional CodeDx installation.

#### Quick Install
1. Install **[docker-compose](https://docs.docker.com/compose/install/)**.
2. If desired, edit the following values in the `docker-compose.yml` file.
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
3. Run `docker-compose up`. Alternatively, run `docker-compose up -d` to detatch and run in the background.
4. To stop, run `docker-compose stop`, and to remove the docker containers automatically created, run `docker-compose down`.

# codedx-tomcat

### Overview
This directory contains scripts that will build a docker image containing a runnable instance of Tomcat and an installation of Code Dx. The image is based on the **[Tomcat](https://hub.docker.com/_/tomcat/)** hosted on **[Docker Hub](https://hub.docker.com/)**.

### Build Instructions
These build instructions are based on Ubuntu 16.04.
1. Install docker using **[these instructions](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-docker-ce-1)**.
2. Unzip the latest Code Dx installation files into a folder named `codedx/`. 
3. As root run the build script: `sudo ./build.sh`
4. An image should be available in your docker installation as well as saved to disk in the `target/` folder with the name of `codedx`. To verify the image exists, run `sudo docker images`. To load the image into other docker instances, or after removing the image, use the command: `sudo docker image load --input target/codedx.tar`

### Manual run instructions (do not follow if you used the quick install instructions above)
These run instructions are based on Ubuntu 16.04.
1. Create a docker network for codedx: `sudo docker network create --driver bridge testnet`
2. Pull the MariaDB docker image into your docker installation: `sudo docker pull mariadb`
3. Create and run a MariaDB container with a root password and a volume, and attach it to the network created above: `docker run --name codedx-db --network testnet -v codedx-db-files:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=codedx -d mariadb`. It is important that the database is running before attempting to create and run a Code Dx/Tomcat container.
4. As root, run the first-run-codedx script: `sudo ./first-run-codedx.sh`. Alternatively, run the following command: `docker run --detach -v codedx-appdata:/opt/codedx --name codedx --network testnet --publish 8080:8080 codedx`. This starts the container, creates a volume named `codedx-appdata` where user data will be stored, and opens port 8080 to the container.
5. To confirm that the Tomcat server hosting codedx started successfully, use the following command: `sudo docker logs codedx | tail`
6. Navigate to http://localhost:8080/codedx, and you should be greeted with the install page.

