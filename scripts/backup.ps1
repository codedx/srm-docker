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
        [Alias('p')]
        [string] $projectName = 'codedx-docker',
		[switch] $usingExternalDb,
		[string] $appDataVolumeName = "$projectName`_codedx-appdata-volume",
        [string] $dbDataVolumeName = "$projectName`_codedx-database-volume",
        [string] $tomcatContainerName = "$projectName`_codedx-tomcat_1",
        [string] $dbContainerName = "$projectName`_codedx-db_1",
        [string] $backupVolumeName
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

$appDataArchiveName = "appdata-backup.tar"
$dbDataArchiveName = "db-backup.tar"

function Test-RunningContainer([string] $containerName) {

	docker container ls | grep $containerName
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
    Write-Verbose "Creating backup of appdata volume, $appDataVolumeName"
    # Create backup of appdata. tar -C is used to set the location for the archive, by doing this we don't store parent directories containing
    # our desired folder. Instead, it's just the contents of the volume in the archive.
    docker run --rm -v $backupName`:/backup -v $appDataVolumeName`:/appdata ubuntu tar -C /appdata -cvf /backup/$appDataArchiveName .
    # Create backup of DB if in use, where an empty value for `dbContainerName` indicates they're using an external DB
    if (!$usingExternalDb) {
        Write-Verbose "Creating backup of DB volume, $dbDataVolumeName"
        docker run --rm -v $backupName`:/backup -v $dbDataVolumeName`:/dbdata ubuntu tar -C /dbdata -cvf /backup/$dbDataArchiveName .
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

Write-Verbose 'Checking containers aren''t running...'
$tomcatContainerName,$dbContainerName | ForEach-Object {

	if (Test-RunningContainer $_) {
		throw "Unable to continue because a backup cannot be created while the container $_ is running. The container can be stopped with the command: docker container stop $_"
	}
}

Write-Verbose "Creating Backup Volume $backupVolumeName"
New-Backup-Volume($backupVolumeName)