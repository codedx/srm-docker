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

4. If this is an additional Code Dx docker-compose environment, you may want to familiarize yourself with these [considerations](#Considerations-When-Using-Multiple-Directories) before the next step.
5. Run `docker-compose up`. Alternatively, run `docker-compose up -d` to detach and run in the background.
6. When the message "The Server is now ready!" appears in the console, navigate to <http://localhost:8080/codedx> to log into your newly spun up Code Dx instance.
7. To stop, run `docker-compose stop`, and to remove the Docker containers automatically created, run `docker-compose down`.

>Note: If you want to migrate data from an existing Code Dx system, refer to [these instructions](./docs/migrate-data.md).

### Custom cacerts

Your Code Dx instance can trust self-signed certificates or certificates issued by certificate authorities not trusted by default. Obtain a copy of the cacerts file from a Java 8 JRE and trust a certificate by running the following keytool command:

```bash
keytool -import -trustcacerts -keystore ./cacerts -file /path/to/cert -alias cert-name
```

>Note: The default password for a Java cacerts file is `changeit`.

You can mount your cacerts file by adding a line to the volumes list in the codedx-tomcat section:

```yaml
    codedx-tomcat:
        image: codedx/codedx-tomcat:v2023.4.3
        environment:
            DB_URL: "jdbc:mysql://codedx-db/codedx"
            DB_DRIVER: "com.mysql.jdbc.Driver"
            DB_USER: "root"
            DB_PASSWORD: "root"
            SUPERUSER_NAME: "admin"
            SUPERUSER_PASSWORD: "secret"
        volumes:
            - codedx-appdata:/opt/codedx
            - /path/to/cacerts:/opt/java/openjdk/lib/security/cacerts
        ports:
            - 8080:8080
        depends_on:
            - codedx-db
```

>Note: Append `:Z` to the extra volume mount when using [selinux](https://docs.docker.com/storage/bind-mounts/#configure-the-selinux-label).

### Custom Props

Code Dx's features can be customized through the configuration file `codedx.props` which, by default, is located in your Tomcat container at `/opt/codedx`. A full list of configuration parameters and how to change them can be found at [Install Guide](https://codedx.com/Documentation/install_guide/CodeDxConfiguration/config-files.html).

For example, if it wasn't desired for Code Dx to remember the username used to login or persist login sessions, then the property `swa.user.rememberme` can be changed from `full` to `off`.

Here's how this can be done in a Docker Compose install:

1. Start your Code Dx Tomcat container

    With our working directory set to where our `docker-compose.yml` file resides, we can start Code Dx and its associated containers via:

    ```bash
    docker-compose -f docker-compose.yml up
    ```

    If an external database install is being used (Code Dx currently requires [MariaDB version 10.3.x](https://mariadb.com/kb/en/release-notes-mariadb-103-series/)), you would instead use the command:

    ```bash
    docker-compose -f docker-compose-external-db.yml up
    ```

2. Wait for Code Dx to be ready

    The Tomcat container will initialize and connect to the configured database. Please wait for this process to complete before proceeding to ensure the installation is in a stable state. Once the Tomcat container outputs the message below you may proceed.

    ```text
    The Server is now ready!
    ```

    If you ran your containers in detached mode so that the container output isn't visible in the console, you can instead look at the container logs via `docker logs codedx-docker_codedx-tomcat_1`.

    You can find the name of your container with `docker container ls --filter name=tomcat` and use that in place of `codedx-docker_codedx-tomcat_1` if yours varies.

    If Code Dx fails to start, there may be something wrong with the configuration (database info for example).

3. Copy `/opt/codedx/codedx.props` locally

    Here we're copying the `codedx.props` file out of the Tomcat container into our local working directory `.`. You can change the destination of this file to something like `C:\Users\[username]\Documents` or `/home/[username]/` where it's more easily accessible, as we'll need to be editing this file later.

    ```bash
    docker cp codedx-docker_codedx-tomcat_1:/opt/codedx/codedx.props .
    ```

4. Edit your local codedx.props (switching from full to off)

    From where you copied `codedx.props` to in the last step, open it with your preferred text editor and change the line

    ```yaml
    swa.user.rememberme = full
    ```

    to

    ```yaml
    swa.user.rememberme = off
    ```

    Code Dx won't remember usernames or persist sessions once we configure Code Dx with the new props file.

5. Copy codedx.props back

    If you're in the same directory as where you copied your props file to, and the Tomcat container is running, then we run the following command to replace the old props file in the container with the new one:

    ```bash
    docker cp codedx.props codedx-docker_codedx-tomcat_1:/opt/codedx/codedx.props
    ```

6. Restart your container

    Code Dx loads the configuration files on boot, therefore we'll need to restart our Tomcat container for our new settings to be properly reflected.

    ```bash
    docker restart codedx-docker_codedx-tomcat_1
    ```

    If you want to stop the running Code Dx instance and you're not using an external database, you can do

    ```bash
    docker-compose -f docker-compose.yml down
    ```

    If Code Dx is configured to use an external database, then you would use:

    ```bash
    docker-compose -f docker-compose-external-db.yml down
    ```

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
        image: codedx/codedx-tomcat:v2023.4.3
        environment:
            DB_URL: "jdbc:mysql://codedx-db/codedx"
            DB_DRIVER: "com.mysql.jdbc.Driver"
            DB_USER: "root"
            DB_PASSWORD: "root"
            SUPERUSER_NAME: "admin"
            SUPERUSER_PASSWORD: "secret"
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

After following the rest of each method's respective setup instructions, Code Dx should now be available over https at the following url: <https://localhost:8443/codedx>

## Upgrading

### Creating a Backup

Before upgrading to the latest Code Dx version you may wish to create a backup of your Code Dx Docker Compose environment. This can be done with the included `backup` script in your `codedx-docker/scripts` folder. Make sure you have PowerShell Core installed, if not, downloads can be found [here](https://github.com/PowerShell/PowerShell#get-powershell).

When running the included scripts and other PowerShell specific commands, make sure you're either in a PowerShell Core terminal environment or the command begins with `pwsh` so it's run by PowerShell Core.

While in the root of the `codedx-docker` folder, stop your containers with the following command before creating the backup to avoid storing incomplete data

```powershell
docker-compose -f docker-compose.yml down
```

Once the containers are stopped:

```powershell
pwsh ./scripts/backup.ps1 -BackupName my-codedx-backup -ComposeConfigPath docker-compose.yml
```

This will create a backup of the following under the name `my-codedx-backup`:

- The database of the `codedx-mariadb` container
  - If using a remote Code Dx database instance this step will be skipped. Steps should be taken to create a backup of the external database instead.
- The app data used by the `codedx-tomcat` container

The name of the backup in the command can also be omitted if it's preferred for a unique name to be generated. The generated name follows the format: `backup-{date}-{time}`

Backups can be automatically removed by the backup script if they meet one of the following criteria:

- Older than 30 days. The default of 30 days may be changed with the `-Retain` option on the backup script. E.g. `-Retain 0` for permanent backups, `-Retain 5` for 5 days, and `-Retain 10:00` for 10 hours.
- Oldest backup when creating a new backup that would exceed the maximum backups stored. By default a maximum of 10 backups will be stored at a time. This can be configured with the `-MaximumBackups` option on the backup script.

You should see the following output when the backup has been successfully created:

```text
Successfully created backup <backup-name>
```

Be cautious of commands such as `docker volume prune`. The volume storing the Code Dx backups is not attached to a container and would be deleted.

### Considerations When Using Multiple Directories

If you're using multiple folders for your Code Dx Docker Compose install (e.g. a folder for each version of Code Dx) and want to use the same volumes across all of them you should specify the project name `-p` option on relevant Docker commands such as `docker-compose up`.

When creating named volumes Docker Compose will prepend the project name, which is the current directory name by default, to the volume name. Meaning if you have a Docker Compose install under the folder `codedx-docker` and another under `codedx-docker-2` their volume names will be distinct and contain different data. Without specifying the `-p` option the following two named volumes would exist:

- `codedx-docker_codedx-appdata-volume`
- `codedx-docker-2_codedx-appdata-volume`

Named volumes are created when doing `docker-compose up`, so if there's a specific name you would like your different installs to share you should specify the project name the first time you execute this command, like so:

```powershell
docker-compose -p codedx up
```

Since the backup script works with these volumes it's important to specify the project name on your backup command if it differs from the default name `codedx-docker`. You can specify it like so:

```powershell
pwsh ./scripts/backup.ps1 -BackupName my-codedx-backup -p my-codedx-project
```

For more advanced usage of the backup script, such as setting the names of your Tomcat and DB containers if they're not the default, see the help info via the command:

```powershell
pwsh -Command get-help .\scripts\backup.ps1 -full
```

### Upgrading to the Latest Code Dx Version

As a final step before upgrading, any desired changes to your Docker Compose configuration (such as alternate port number) should be taken. Having these changes in place before the upgrade allows for Git to point out possible conflicts which you'll be able to resolve.

The preferred method for upgrading is by pulling the latest changes. While you're in the root of your docker-compose folder:

```powershell
git pull
```

If your Docker Compose environment already has the latest changes you'll see output from Git saying it's already up to date. Otherwise, you may have to resolve merge conflicts if changes were made in the docker-compose folder before the upgrade, such as modifying the docker-compose.yml file.

Alternatively, you can download the ZIP representing the latest codedx-docker update. **Note that if you're using the ZIP to replace an existing folder, any changes you made in the Code Dx Docker Compose root folder (such as the docker-compose.yml file) will be overwritten unless you carry over your changes to the new Docker Compose folder.** This merge process will be done for you if you use the Git approach above. The ZIP can be downloaded here: <https://github.com/codedx/codedx-docker/archive/refs/heads/master.zip>

Note that pulling the latest files via Git increases the likelihood that all Docker Compose commands run from the same directory and it's less likely to come across unexpected behavior due to [how docker-compose sets project names](#Considerations-When-Using-Multiple-Directories).

In order for the latest Code Dx changes to be applied we'll have to restart our containers. First, we need to stop running containers. Replace the docker-compose.yml file in this command with the compose file you're using if it differs.

**(Make sure not to use the -v switch for `down`, we want to keep our volumes)**

```powershell
docker-compose -f docker-compose.yml down
```

### Running Code Dx After Upgrade

After successfully upgrading, you can run the following command to see the effects of the upgrade:

```powershell
docker-compose -f docker-compose.yml up
```

### Restoring From a Backup

In the event that an upgrade has gone wrong or existing Code Dx data has been corrupted/deleted, you may restore from a [previously created backup](#Creating-a-Backup).

This can be done with the included `restore` script in your `codedx-docker/scripts` folder. This will restore Code Dx data from a provided backup name which was either specified or generated when creating the backup.

Make sure your containers aren't running before executing the script to avoid unexpected behavior.

Assuming no defaults have been changed about the Code Dx Docker Compose environment:

```powershell
pwsh ./scripts/restore.ps1 -BackupName [backup-name]
```

Alternatively if you're not sure of the current backups on your system you can omit the `-BackupName` option and a listing of backups will be displayed along with a prompt for you to select one.

And if defaults were modified (e.g. project name, app data volume) then refer to the script's help for specifying these values

```powershell
pwsh -Command get-help .\scripts\restore.ps1 -full
```

After running the command, you should see

```text
Successfully restored backup <backup-name>
```
