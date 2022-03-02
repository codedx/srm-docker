<#PSScriptInfo
.VERSION 1.0.0
.GUID a56b7e15-a300-4da7-85b6-8c3bdff8d897
.AUTHOR Code Dx
#>

<#
.DESCRIPTION
This script restores the data present in a Code Dx backup volume to the volumes the Code Dx docker-compose
environment depends on (appdata for tomcat, db for maraidb). If using a remote DB, only appdata will be restored and
restoring the database will not be automated as part of this script.
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

function Restore-Backup-Volume([string] $backupName) {
    Write-Verbose "Removing volume $appDataVolumeName"
    docker volume rm $appDataVolumeName
    Write-Verbose "Removing volume $dbDataVolumeName"
    docker volume rm $dbDataVolumeName
    Write-Verbose "Copying backup data from $backupVolumeName to new volumes"
    if (!$usingExternalDb) {
        docker run --rm -v $appDataVolumeName`:/appdata -v $dbDataVolumeName`:/dbdata -v $backupVolumeName`:/backup ubuntu bash -c "cd /backup && tar -xvf $appDataArchiveName --directory=/appdata --strip 1 && tar -xvf $dbDataArchiveName --directory=/dbdata"
    }
    else {
        docker run --rm -v $appDataVolumeName`:/appdata -v $backupVolumeName`:/backup ubuntu bash -c "cd /backup && tar -xvf $appDataArchiveName --directory=/appdata"
    }
}

if ($usingExternalDb) {
    # So long as the user hasn't explicitly set the appdata volume name,
    # update appdata volume name to the default for external database configuration
    if (!$appDataVolumeName.Equals("$projectName`_codedx-appdata-volume")) {
        $appDataVolumeName = "$projectName`_codedx-appdata-ex-db-volume"
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

Write-Verbose "Restoring Backup Volume $backupVolumeName"
Restore-Backup-Volume($backupVolumeName)

if ($LASTEXITCODE -eq 0) {
    Write-Verbose "Restoring Backup Volume $backupVolumeName successful"
}