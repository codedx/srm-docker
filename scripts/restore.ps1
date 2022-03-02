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
        [string] $ProjectName = 'codedx-docker',
		[switch] $UsingExternalDb,
		[string] $AppDataVolumeName = "$ProjectName`_codedx-appdata-volume",
        [string] $DbDataVolumeName = "$ProjectName`_codedx-database-volume",
        [string] $TomcatContainerName = "$ProjectName`_codedx-tomcat_1",
        [string] $DbContainerName = "$ProjectName`_codedx-db_1",
        [string] $BackupVolumeName
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

. $PSScriptRoot/common.ps1

function Restore-Backup-Volume([string] $BackupName) {
    Write-Verbose "Removing volume $AppDataVolumeName"
    docker volume rm $AppDataVolumeName
    Write-Verbose "Removing volume $DbDataVolumeName"
    docker volume rm $DbDataVolumeName
    Write-Verbose "Copying backup data from $BackupName to new volumes"
    if (!$UsingExternalDb) {
        docker run --rm -v $AppDataVolumeName`:/appdata -v $DbDataVolumeName`:/dbdata -v $BackupName`:/backup ubuntu bash -c "cd /backup && tar -xvf $AppDataArchiveName --directory=/appdata && tar -xvf $DbDataArchiveName --directory=/dbdata"
    }
    else {
        docker run --rm -v $AppDataVolumeName`:/appdata -v $BackupName`:/backup ubuntu bash -c "cd /backup && tar -xvf $AppDataArchiveName --directory=/appdata"
    }
}

if ($usingExternalDb) {
    # So long as the user hasn't explicitly set the appdata volume name,
    # update appdata volume name to the default for external database configuration
    if (!$AppDataVolumeName.Equals("$ProjectName`_codedx-appdata-volume")) {
        $AppDataVolumeName = "$ProjectName`_codedx-appdata-ex-db-volume"
    }
}

Test-Script-Can-Run($TomcatContainerName, $DbContainerName)

Write-Verbose "Restoring Backup Volume $BackupVolumeName"
Restore-Backup-Volume($BackupVolumeName)

if ($LASTEXITCODE -eq 0) {
    Write-Verbose "Sucessfully restored backup volume $BackupVolumeName"
}