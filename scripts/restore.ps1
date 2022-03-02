<#PSScriptInfo
.VERSION 1.0.0
.GUID a56b7e15-a300-4da7-85b6-8c3bdff8d897
.AUTHOR Code Dx
#>

<#
.SYNOPSIS
Restores a Code Dx Docker Compose install with the data in a provided backup volume

.DESCRIPTION
This script restores the data present in a Code Dx backup volume to the volumes the Code Dx docker-compose
environment depends on (appdata for tomcat, db for maraidb). If using a remote DB, only appdata will be restored and
restoring the database will not be automated as part of this script.

.PARAMETER ProjectName
The name used for prefacing volume and container names.

The project name is used by docker-compose and preceeds the name of docker resources
such as containers and volumes. By default, this is set to the name of the
containing directory of the compose file.

If you have multiple Code Dx Docker Compose installations, you should specify the project name to refer
to a specific one.

.PARAMETER UsingExternalDb
This switch's presence indicates this Code Dx Docker Compose install is utilizing an external database,
therefore, the backup script will not attempt to create a backup of the database.

The generated backup volume will only contain a backup of the appdata.

.PARAMETER AppDataVolumeName
By default, this is the project name + '_' + 'codedx-appdata-volume'.

If the tomcat container depends on a volume name other than this, the name from the docker-compose config file should be specified with this parameter. A named volume will be
generated with the name provided by this parameter.

.PARAMETER DbDataVolumeName
By default, this is the project name + '_' + 'codedx-database-volume'. Affects behavior when -UsingExternalDb is false.

If the database container depends on a volume name other than the default, the name from the docker-compose config file should be specified with this parameter. A named volume will be
generated with the name provided by this parameter.

.PARAMETER TomcatContainerName
By default, this is the project name + '_' + 'codedx-tomcat_1'.

If the docker-compose config file specifies a service name other than 'codedx-tomcat', that updated value should be specified with this parameter.

.PARAMETER DbContainerName
By default, this is the project name + '_' + 'codedx-db_1'. Affects behavior when -UsingExternalDb is false.

If the docker-compose config file specifies a service name other than 'codedx-db', that updated value should be specified with this parameter.

.PARAMETER BackupVolumeName
The name of the backup volume to restore from.

.LINK
https://github.com/codedx/codedx-docker#restoring-from-a-backup

#>

param (
        [Alias('p')]
        [string] $ProjectName = 'codedx-docker',
        [switch] $UsingExternalDb,
        [string] $AppDataVolumeName = "$ProjectName`_codedx-appdata-volume",
        [string] $DbDataVolumeName = "$ProjectName`_codedx-database-volume",
        [string] $TomcatContainerName = "$ProjectName`_codedx-tomcat_1",
        [string] $DbContainerName = "$ProjectName`_codedx-db_1",
        [Parameter(Mandatory=$true)]
        [string] $BackupVolumeName
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

. $PSScriptRoot/common.ps1

function Restore-Backup-Volume([string] $BackupName) {
    Write-Verbose "Removing volume $AppDataVolumeName"
    # Check if the volume exists before deleting it. It's possible a user accidently did `docker-compose down -v` and deleted
    # the associated volumes and is trying to run the restore script. Trying to remove a non-existent volume will be an error.
    (docker volume ls | grep $AppDataVolumeName) -and (docker volume rm $AppDataVolumeName) >$null

    Write-Verbose "Removing volume $DbDataVolumeName"
    (docker volume ls | grep $DbDataVolumeName) -and (docker volume rm $DbDataVolumeName) >$null

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
