
$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

Import-Module 'pester' -ErrorAction SilentlyContinue
if (-not $?) {
	Write-Host 'Pester is not installed, so this test cannot run. Run pwsh, install the Pester module (Install-Module Pester), and re-run this script.'
	exit 1
}

$location = Join-Path $PSScriptRoot '../..'
Push-Location $location

Describe 'version.ps1' {

	It 'mismatched version updates' {

		Mock Get-Content  {
			$fileSource[$path]
		}

		Mock Set-Content {
			$fileContent[$path[0]] = $value
		}

		$oldVersion = 'codedx/codedx-tomcat:v1.2.3'

		$newTag = 'v3.2.1'
		$newVersion = "codedx/codedx-tomcat:$newTag"

		. ./.version/version.ps1 $newTag

		$fileContent.Keys | ForEach-Object {
			$fileContent[$_] | Select-String -Pattern "image: $newVersion" -SimpleMatch -Quiet | Should -BeTrue
			$fileContent[$_] | Select-String -Pattern "image: $oldVersion" -SimpleMatch -Quiet | Should -BeFalse
		}

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 3
		Assert-MockCalled -CommandName 'Set-Content' -Exactly 3
	}

	It 'matched version is a no-op' {

		Mock Get-Content  {
			$fileSource[$path]
		}

		Mock Set-Content {
			$fileContent[$path[0]] = $value
		}

		$oldVersion = 'codedx/codedx-tomcat:v1.2.3'
		$newTag = 'v1.2.3'

		. ./.version/version.ps1 $newTag

		$fileContent.Keys | ForEach-Object {
			$fileContent[$_] | Select-String -Pattern "image: $oldVersion" -SimpleMatch -Quiet | Should -BeTrue
		}

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 3
		Assert-MockCalled -CommandName 'Set-Content' -Exactly 3
	}

	BeforeAll {
		$global:fileSource = @{
			'./docker-compose.yml' = @'
version: '2'
services:
	codedx-db:
		image: bitnami/mariadb:10.3.25-debian-10-r18
		environment:
			- MARIADB_ROOT_PASSWORD=root
			- MARIADB_DATABASE=codedx
			- MARIADB_EXTRA_FLAGS=--optimizer_search_depth=0 --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci --lower_case_table_names=1
		volumes:
			- codedx-database-volume:/bitnami/mariadb
	codedx-tomcat:
		image: codedx/codedx-tomcat:v1.2.3
		environment:
			- DB_URL=jdbc:mysql://codedx-db/codedx
			- DB_DRIVER=com.mysql.jdbc.Driver
			- DB_USER=root
			- DB_PASSWORD=root
			- SUPERUSER_NAME=admin
			- SUPERUSER_PASSWORD=secret
		volumes:
			- codedx-appdata-volume:/opt/codedx
		ports:
			- 8080:8080
		depends_on:
			- codedx-db
volumes:
	codedx-database-volume:
	codedx-appdata-volume:
'@
			'./docker-compose-external-db.yml' = @'
version: '2'
services:
	codedx-tomcat:
		image: codedx/codedx-tomcat:v1.2.3
		environment:
			- DB_URL=jdbc:mysql://codedx-db/codedx
			- DB_DRIVER=com.mysql.jdbc.Driver
			- DB_USER=root
			- DB_PASSWORD=root
			- SUPERUSER_NAME=admin
			- SUPERUSER_PASSWORD=secret
		volumes:
			- codedx-appdata-volume:/opt/codedx
		ports:
			- 8080:8080
volumes:
	codedx-appdata-volume:
'@
			'./README.md' = @'
## HTTP Over SSL

This Tomcat container can support HTTP over SSL. For example, generate a self-signed certificate with `openssl` (or better yet, obtain a real certificate from a certificate authority):

```bash
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=US/ST=New York/L=Northport/O=Code Dx/CN=localhost" -keyout ./ssl.key -out ./ssl.crt
```

The `server.xml` file contains a configuration that supports SSL using **[Tomcat's SSL capability](https://tomcat.apache.org/tomcat-8.0-doc/ssl-howto.html)**.

This template can be mounted over the existing `server.xml` in the Docker image. The SSL certificate and private key must also be mounted.

To configure, edit the `docker-compose.yml` codedx-tomcat section to look like:

```yaml
	codedx-tomcat:
		image: codedx/codedx-tomcat:v1.2.3
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
'@
		}
	}

	BeforeEach {
		$global:fileContent = @{}
	}
}
