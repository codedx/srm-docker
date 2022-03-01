<#PSScriptInfo
.VERSION 1.0.0
.GUID a56b7e15-a300-4da7-85b6-8c3bdff8d897
.AUTHOR Code Dx
#>

<#
.DESCRIPTION
This script creates a backup of volumes created automatically in a Code Dx docker-compose
install. These backups can then be used by a restore script.
#>

param (
		[string] $tomcatContainerName = 'codedx-docker_codedx-tomcat_1',
		[string] $dbContainerName = 'codedx-docker_codedx-db_1',
		[string] $appDataPath = '/opt/codedx',
        [string] $dbDataPath = '/bitnami/mariadb',
        [string] $backupVolumeName,
        [switch] $usingExternalDb
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

$appDataArchiveName = "appdata-backup.tar"
$dbDataArchiveName = "db-backup.tar"

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

function New-Backup-Volume([string] $backupName) {
    Write-Verbose "Creating backup of appdata at $tomcatContainerName`:$appDataPath"
    # Create backup of appdata. tar -C is used to set the location for the archive, by doing this we don't store parent directories containing
    # our desired folder. Instead, it's just the contents of $appDataPath in the archive.
    docker run --rm --volumes-from $tomcatContainerName -v $backupName`:/backup ubuntu tar -C $appDataPath -cvf /backup/$appDataArchiveName .
    # Create backup of DB if in use, where an empty value for `dbContainerName` indicates they're using an external DB
    if (!$usingExternalDb) {
        Write-Verbose "Creating backup of DB at $dbContainerName`:$dbDataPath"
        docker run --rm --volumes-from $dbContainerName -v $backupName`:/backup ubuntu tar -C $dbDataPath -cvf /backup/$dbDataArchiveName .
    }
    else {
        Write-Verbose 'Skipping backing up database due to -usingExternalDb being true'
    }
}

Write-Verbose 'Checking PATH prerequisites...'
'docker','docker-compose' | ForEach-Object {

	if (-not (Test-AppCommandPath $_)) {
		throw "Unable to continue because $_ could not be found. Is $_ installed and included in your PATH?"
	}
}

Write-Verbose 'Checking running containers...'
$tomcatContainerName,$dbContainerName | ForEach-Object {

	if (-not (Test-RunningContainer $_)) {
		throw "Unable to continue because a running container named $_ could not be found. Is Code Dx running with Docker Compose and did you specify the correct script parameters (-tomcatContainerName and -dbContainerName)?"
	}
}

Write-Verbose "Creating Backup Volume $backupVolumeName"
New-Backup-Volume($backupVolumeName)