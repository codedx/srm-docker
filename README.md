# codedx-docker

This repository contains the scripts necessary to create docker images that comprise a fully functional CodeDx installation.

# codedx-tomcat

### Overview
This directory contains scripts that will build a docker image containing a runnable instance of Tomcat and an installation of CodeDx. The image is based on the **[Tomcat](https://hub.docker.com/_/tomcat/)** hosted on **[Docker Hub](https://hub.docker.com/)**.

### Build Instructions
These build instructions are based on Ubuntu 16.04.
1. Install docker using **[these instructions](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-docker-ce-1)**.
2. Unzip the latest CodeDx installation files into a folder named `codedx/`. 
3. Edit `codedx/codedx.props` to contain the MariaDB credentials that will be specified in the run instructions below.
4. As root run the build script: `sudo ./build.sh`
5. An image should be available in your docker installation as well as saved to disk in the `target/` folder with the name of `codedx`. To verify the image exists, run `sudo docker images`. To load the image into other docker instances, or after removing the image, use the command: `sudo docker image load --input target\codedx.tar`

### Run instructions
These run instructions are based on Ubuntu 16.04.
1. Create a docker network for codedx: `sudo docker network create --driver bridge testnet`
2. Pull the MariaDB docker image into your docker installation: `sudo docker pull mariadb`
3. Create and run a MariaDB container with a root password, and attach it to the network created above: `sudo docker run --name codedx-db --network testnet -e MYSQL_ROOT_PASSWORD=root -p 3306:3306 -d mariadb`
4. Connect to the MariaDB container: `sudo docker exec -i -t codedx-db bash`
5. Log into the MariaDB server: `mysql -uroot -p` (enter password when prompted)
6. Create the codedx database: `CREATE DATABASE codedx;`
7. Type `exit` to exit the mysql prompt, and `exit` again to leave the MariaDB docker container.
8. As root, run the first-run-codedx script: `sudo ./first-run-codedx.sh`
9. To confirm that the Tomcat server hosting codedx started successfully, use the following command: `sudo docker logs codedx | tail`
10. Navigate to http://localhost:8080/codedx, and you should be greeted with the install page.
