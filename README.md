# codedx-docker

This repository lets you create a [Code Dx](https://www.codedx.com) installation using Docker Compose. A Docker-based installation of Code Dx contains two parts: the database image, based on MariaDB, and the Tomcat image that hosts the Code Dx web application. The Tomcat Docker container will be networked with the MariaDB container to allow Code Dx to store data.

The installation uses `docker-compose` to stand up a functional instance of Code Dx automatically, pulling the Tomcat/Code Dx image from Docker Hub, and starting a properly configured MariaDB container.

## Installation

### Overview
This section details how to start up a functional instance of Code Dx using Docker, accessible via port 8080.

### Instructions
1. Install Docker using **[these instructions](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-docker-ce-1)**.
2. Install **[docker-compose](https://docs.docker.com/compose/install/)**.
3. If desired, edit the following values in the `docker-compose.yml` file.
- The following configuration values affect the database container:
  - MARIADB_ROOT_PASSWORD: The password for MariaDB's root user.
  - MARIADB_DATABASE: The name of the database to be created automatically when the container is started.
- The following configuration values affect the Tomcat based Code Dx container:
  - DB_URL: The url that Code Dx uses to connect to it's database.
  - DB_DRIVER: The jdbc database driver that Code Dx uses.
  - DB_USER: The database user Code Dx connects with.
  - DB_PASSWORD: The password Code Dx connects with.
  - SUPERUSER_NAME: The root administrator name for Code Dx.
  - SUPERUSER_PASSWORD: The password for the Code Dx root administrator.
  - ports: The list of values underneath this header controls the ports forwarded from the Docker instance to the host machine. The left value represents the port bound on the host machine, the right value represents the port bound in the Docker container. If there is a port conflict on the host machine, alter the left value.
4. Run `docker-compose up`. Alternatively, run `docker-compose up -d` to detach and run in the background.
5. When the message "The Server is now ready!" appears in the console, navigate to http://localhost:8080/codedx to log into your newly spun up Code Dx instance.
6. To stop, run `docker-compose stop`, and to remove the Docker containers automatically created, run `docker-compose down`.

>Note: If you want to migrate data from an existing Code Dx system, refer to [these instructions](./docs/migrate-data.md).

### Custom cacerts

Your Code Dx instance can trust self-signed certificates or certificates issued by certificate authorities not trusted by default. Obtain a copy of the cacerts file from a Java 8 JRE and trust a certificate by running the following keytool command:

```
keytool -import -trustcacerts -keystore ./cacerts -file /path/to/cert -alias cert-name
```

>Note: The default password for a Java cacerts file is `changeit`.

You can mount your cacerts file by adding a line to the volumes list in the codedx-tomcat section:

```yaml
    codedx-tomcat:
        image: codedx/codedx-tomcat:v5.4.15.1
        environment:
            - DB_URL=jdbc:mysql://codedx-db/codedx
            - DB_DRIVER=com.mysql.jdbc.Driver
            - DB_USER=root
            - DB_PASSWORD=root
            - SUPERUSER_NAME=admin
            - SUPERUSER_PASSWORD=secret
        volumes:
            - codedx-appdata:/opt/codedx
            - /path/to/cacerts:/opt/java/openjdk/jre/lib/security/cacerts
        ports:
            - 8080:8080
        depends_on:
            - codedx-db
```

>Note: Append `:Z` to the extra volume mount when using [selinux](https://docs.docker.com/storage/bind-mounts/#configure-the-selinux-label).

### Custom Props

Code Dx's features can be customized through the configuration file `codedx.props` which, by default, is located in your tomcat container's `codedx-appdata` volume (typically located at `/opt/codedx`). A full list of configuration parameters and how to change them can be found at [Install Guide](https://codedx.com/Documentation/InstallGuide.html#CodeDxPropertiesFile).

For example, if it wasn't desired for Code Dx to remember the username used to login or persist login sessions, then the property `swa.user.rememberme` can be changed from `full` to `off`.

Here's how this can be done in a Docker Compose install:

1. Start your Code Dx Tomcat container

With our working directory set to where our `docker-compose.yml` file resides, the Tomcat container configured by the `codedx-tomcat` service can be started with the command:

```bash
docker-compose start codedx-tomcat
```

2. Copy `/opt/codedx/codedx.props` locally

Here we're copying the `codedx.props` file out of the Tomcat container into our local working directory `.`. You can change the destination of this file to something like `C:\Users\[username]\Documents` or `/home/[username]/` where it's more easily accessible, as we'll need to be editing this file later.

You can find the name of your container with `docker container ls --filter name=tomcat` and use that in place of `codedx-docker_codedx-tomcat_1` if yours varies.

```bash
docker cp codedx-docker_codedx-tomcat_1:/opt/codedx/codedx.props .
```

3. Edit your local codedx.props (switching from full to off)

From where you copied `codedx.props` to in the last step, open it with your preferred text editor and change the line

```yaml
swa.user.rememberme = full
```

to

```yaml
swa.user.rememberme = off
```

Code Dx won't remember usernames or persist sessions once we configure Code Dx with the new props file.

4. Copy codedx.props back

If you're in the same directory as where you copied your props file to, and the tomcat container is running, then we run the following command to replace the old props file in the container with the new one:

```bash
docker cp codedx.props codedx-docker_codedx-tomcat_1:/opt/codedx/codedx.props
```

5. Restart your container

Code Dx loads the configuration files on boot, therefore we'll need to restart our tomcat container for our new settings to be properly reflected.

```bash
docker restart codedx-docker_codedx-tomcat_1
```

(If you want to stop the Tomcat container running in the background run the command `docker compose stop codedx-tomcat`)

### HTTP Over SSL

This Tomcat container can support HTTP over SSL. For example, generate a self-signed certificate with `openssl` (or better yet, obtain a real certificate from a certificate authority):

```bash
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=US/ST=New York/L=Northport/O=Code Dx/CN=localhost" -keyout ./ssl.key -out ./ssl.crt
```

The `server.xml` file contains a configuration that supports SSL using **[Tomcat's SSL capability](https://tomcat.apache.org/tomcat-9.0-doc/ssl-howto.html)**.

This template can be mounted over the existing `server.xml` in the Docker image. The SSL certificate and private key must also be mounted.

Update your codedx-tomcat section with SSL and server.xml volume mounts and switch ports from 8080:8080 to 8443:8443. For example, below is a version of `docker-compose.yml` with the use of port 8443 and extra volume mounts for server.xml, ssl.key, and ssl.crt. Apply a similar update to `docker-compose-external-db.yml` if you're using an external database.

```yaml
    codedx-tomcat:
        image: codedx/codedx-tomcat:v5.4.15.1
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

>Note: Append `:Z` to the extra volume mounts when using [selinux](https://docs.docker.com/storage/bind-mounts/#configure-the-selinux-label).

After following the rest of each method's respective setup instructions, Code Dx should now be available over https at the following url: https://localhost:8443/codedx
