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

function New-Backup-Volume([string] $BackupName) {
    Write-Verbose "Creating backup of appdata volume, $AppDataVolumeName"
    # Create backup of appdata. tar -C is used to set the location for the archive, by doing this we don't store parent directories containing
    # our desired folder. Instead, it's just the contents of the volume in the archive.
    docker run --rm -v $BackupName`:/backup -v $AppDataVolumeName`:/appdata ubuntu tar -C /appdata -cvf /backup/$AppDataArchiveName .
    # Create backup of DB if in use, where an empty value for `dbContainerName` indicates they're using an external DB
    if (!$UsingExternalDb) {
        Write-Verbose "Creating backup of DB volume, $DbDataVolumeName"
        docker run --rm -v $BackupName`:/backup -v $DbDataVolumeName`:/dbdata ubuntu tar -C /dbdata -cvf /backup/$DbDataArchiveName .
    }
    else {
        Write-Verbose 'Skipping backing up database due to -usingExternalDb being true'
    }
}

Test-Script-Can-Run($TomcatContainerName, $DbContainerName)

Write-Verbose "Creating Backup Volume $BackupVolumeName"
New-Backup-Volume($BackupVolumeName)
Write-Verbose "Successfully created backup volume $BackupVolumeName"