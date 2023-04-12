# Use Amazon RDS with MariaDB engine for your Code Dx database

Here are the steps to run Code Dx with Docker Compose and an Amazon RDS database instance.

>Note: Code Dx currently requires [MariaDB version 10.6.x](https://mariadb.com/kb/en/release-notes-mariadb-106-series/).

1. Follow the [Use Amazon RDS with MariaDB engine for your Code Dx database](https://github.com/codedx/codedx-kubernetes/blob/master/setup/core/docs/db/use-rds-for-code-dx-database.md) instructions to provision a new Amazon RDS MariaDB database instance.

2. Download the [Amazon RDS root certificate](https://s3.amazonaws.com/rds-downloads/rds-ca-2019-root.pem).

3. Obtain a copy of the cacerts file from a Java 8 distribution, which will include the keytool program you will need in the next step.

4. Follow the [Custom cacerts](https://github.com/codedx/codedx-docker#custom-cacerts) instructions to add the rds-ca-2019-root.pem file to your cacerts file and update the volumes section in your docker-compose-external-db.yml with a line for your cacerts file. You can use the following keytool command to trust the rds-ca-2019-root.pem certificate you downloaded.

    ```
    keytool -import -trustcacerts -keystore ./cacerts -file ./rds-ca-2019-root.pem -alias rds-ca-2019-root
    ```

5. Edit the docker-compose-external-db.yml file:

    a. Enter the database username (from Step 2) for the DB_USER parameter

    b. Enter the database password (from Step 2) for the DB_PASSWORD parameter

    c. Specify a Code Dx admin username for the SUPERUSER_NAME parameter

    d. Specify a Code Dx admin password for the SUPERUSER_PASSWORD parameter

    e. Update the DB_URL parameter by specifying your RDS database instance hostname

    f. Update the DB_URL parameter by specifying your Code Dx database name (from Step 2, which uses `codedxdb` by default)

    g. Append the following SSL-related parameters to the DB_URL parameter:

    ```
    &useSSL=true&requireSSL=true
    ```

    Here is an example of a DB_URL parameter value using hostname `amazon-rds-hostname` and database name `codedxdb`:

    ```
    "jdbc:mysql://amazon-rds-hostname/codedxdb?sessionVariables=sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'&useSSL=true&requireSSL=true"
    ```

6. Follow the [HTTP Over SSL](https://github.com/codedx/codedx-docker#http-over-ssl) instructions if your deployment requires TLS/SSL.

7. Start Code Dx with the following command:

    ```
    docker-compose -f ./docker-compose-external-db.yml up -d
    ```

    You can run the following commands to view Code Dx log data (assumes a codedx-docker_codedx-tomcat_1 container name):

    docker exec codedx-docker_codedx-tomcat_1 tail -f /opt/codedx/log-files/codedx.log

    docker logs codedx-docker_codedx-tomcat_1
