<#PSScriptInfo
.VERSION 1.1.0
.GUID a56b7e15-a300-4da7-85b6-8c3bdff8d897
.AUTHOR Software Risk Manager
#>

<#
.DESCRIPTION
This script helps you migrate Software Risk Manager data from a system created by the
Software Risk Manager Installer to a Software Risk Manager deployment running with Docker Compose.
#>

param (
		[string] $tomcatContainerName = 'codedx-docker-codedx-tomcat-1',
		[string] $dbContainerName = 'codedx-docker-codedx-db-1',
		[string] $dbName = 'codedx',
		[string] $dbDumpFilePath,
		[string] $appDataPath,
		[string] $dbRootPwd,
		[switch] $skipCodeDxRestart,
		[switch] $externalDatabase
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

function Test-RunningContainer([string] $containerName) {

	docker exec $containerName echo $containerName
	$LASTEXITCODE -eq 0
}

function Test-AppCommandPath([string] $commandName) {

	$command = Get-Command $commandName -Type Application -ErrorAction SilentlyContinue
	if ($null -eq $command) {
		return $null
	}
	$command.Path
}

if (-not $externalDatabase) {
	if ($dbDumpFilePath -eq '') {
		$dbDumpFilePath = Read-Host 'Enter the path to your mysqldump file'
	}

	Write-Verbose 'Checking database dump file path...'
	if (-not (Test-Path $dbDumpFilePath -PathType Leaf)) {
		throw "Unable to find mysqldumpfile at $dbDumpFilePath."
	}
}

if ($appDataPath -eq '') { 
	$appDataPath = Read-Host 'Enter the path to your Software Risk Manager AppData folder'
}

Write-Verbose 'Checking appdata path...'
if (-not (Test-Path $appDataPath -PathType Container)) {
	throw "Unable to find Software Risk Manager AppData folder at $appDataPath."
}

Write-Verbose 'Checking appdata/analysis-files path...'
$analysisFiles = join-path $appDataPath 'analysis-files'
if (-not (Test-Path $analysisFiles -PathType Container)) {
	throw "Unable to find Software Risk Manager AppData analysis-files folder at $analysisFiles."
}

if ($dbRootPwd -eq '') {
	$bstr      = [Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host 'Enter the password for the docker MariaDB root user' -AsSecureString))
	$dbRootPwd = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
}

Write-Verbose 'Checking PATH prerequisites...'
'docker','docker-compose' | ForEach-Object {

	if (-not (Test-AppCommandPath $_)) {
		throw "Unable to continue because $_ could not be found. Is $_ installed and included in your PATH?"
	}
}

Write-Verbose 'Checking running containers...'

$containersToCheck = @($tomcatContainerName)
if (-not $externalDatabase) {
	$containersToCheck += $dbContainerName
}

$containersToCheck | ForEach-Object {

	if (-not (Test-RunningContainer $_)) {
		throw "Unable to continue because a running container named $_ could not be found. Is Software Risk Manager running with Docker Compose and did you specify the correct script parameters (-tomcatContainerName and -dbContainerName)?"
	}
}
if (-not $externalDatabase) {
	Write-Verbose "Dropping database named $dbName..."
	docker exec $dbContainerName mysql -uroot --password="$dbRootPwd" -e "DROP DATABASE IF EXISTS $dbName"
	if ($LASTEXITCODE -ne 0) {
		throw 'Unable to drop database'
	}

    Write-Verbose "Creating database named $dbName..."
    docker exec $dbContainerName mysql -uroot --password="$dbRootPwd" -e "CREATE DATABASE $dbName"
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to create database'
    }

    Write-Verbose 'Creating temporary directory...'
    docker exec $dbContainerName mkdir -p /tmp/srm
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to create directory'
    }

    Write-Verbose 'Copying database dump file to container...'
    docker cp $dbDumpFilePath $dbContainerName`:/tmp/srm/dump-srm.sql
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to copy dump file to directory'
    }

    Write-Verbose 'Importing database dump file (may take a while)...'
    docker exec $dbContainerName "bash" "-c" "mysql -uroot --password=""$dbRootPwd"" $dbName < /tmp/srm/dump-srm.sql"
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to import database dump file'
    }

    Write-Verbose 'Deleting database dump file...'
    docker exec $dbContainerName rm -Rf /tmp/srm
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to delete database dump file'
    }
} else {
	$externalDatabaseInstructions = @'

Since your SRM deployment uses an external database (one that you maintain on your own
that is not installed or updated by the SRM deployment script), you must restore the dump-srm.sql file you
created in Step 5 of the Migrate SRM Data to Docker Compose instructions.

You can restore mysqldump files using a command that looks like this:

  mysql -uroot -p srmdb < dump-srm.sql

Note: Replace 'root' and 'srmdb' as necessary.
'@
	Write-Host $externalDatabaseInstructions
	Read-Host -Prompt 'Restore your database (see above) and then press Enter to continue...'
}

Write-Verbose 'Deleting directories...'
'/opt/codedx/analysis-files','/opt/codedx/keystore','/opt/codedx/mltriage-files' | ForEach-Object {

    Write-Verbose "Deleting directory $_..."
    docker exec $tomcatContainerName "bash" "-c" "if test -d $_; then rm -Rf $_; fi"
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to delete directory $_"
    }
}

Write-Verbose 'Copying directories...'
'analysis-files','keystore','mltriage-files' | ForEach-Object {

	$owner = 'codedx'

	$path = join-path $appDataPath $_
	if (Test-Path $path -PathType Container) {

		$destinationDir = "/opt/codedx/$_"

		Write-Verbose "Copying directory $path to $destinationDir..."
		docker cp $path $tomcatContainerName`:/opt/codedx
		if ($LASTEXITCODE -ne 0) {
			throw "Unable to copy directory $path"
		}

		Write-Verbose "Changing directory ownership of '$destinationDir' to $owner..."
		docker exec -u 0 $tomcatContainerName chown -R $owner`:$owner $destinationDir
	}
}

if ($skipCodeDxRestart) {

	Write-Host 'Data migration complete. Software Risk Manager must be restarted at this time (run: docker-compose restart)'
	return
}

Write-Verbose 'Restarting Software Risk Manager...'
Push-Location (join-path $PSScriptRoot '..')
docker-compose restart
if ($LASTEXITCODE -ne 0) {
	throw 'Unable to restart Software Risk Manager'
}

Write-Host 'Done'
