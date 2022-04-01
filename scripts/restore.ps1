<#PSScriptInfo
.VERSION 1.0.0
.GUID d6b73bb9-7106-4f53-b992-3cf4d98c4746
.AUTHOR Code Dx
#>

<#
.SYNOPSIS
Restores a Code Dx Docker Compose install with the data in a provided backup volume

.DESCRIPTION
This script restores the data present in a Code Dx backup volume to the volumes the Code Dx docker-compose
environment depends on (appdata for tomcat, db for maraidb).

.PARAMETER ProjectName
The name used for prefacing volume and container names.

The project name is used by docker-compose and preceeds the name of docker resources
such as containers and volumes. By default, this is set to the name of the
containing directory of the compose file.

If you have multiple Code Dx Docker Compose installations, you should specify the project name to refer
to a specific one.

.PARAMETER AppDataVolumeName
If the Tomcat container depends on a volume name other than this, the name from the docker-compose config file (with the project name included) should be specified with this parameter.

.PARAMETER DbDataVolumeName
If the database container depends on a volume name other than the default, the name from the docker-compose config file (with the project name included) should be specified with this parameter.

.PARAMETER CodeDxTomcatServiceName
If the Tomcat service name is not 'codedx-tomcat' this should be set to that service name

.PARAMETER CodeDxDbServiceName
If the DB service name is not 'codedx-db' this should be set to that service name

.PARAMETER ComposeConfigPath
By default, this points to the default docker-compose config file that includes a database container.

If using an external database, this should be set to the path of your external db docker-compose file.

.PARAMETER BackupName
The name of the desired backup to restore from in the Code Dx backup volume.

If not specified, a listing of the current backups will be displayed along with a prompt for entering the name of one of those backups.

.LINK
https://github.com/codedx/codedx-docker#restoring-from-a-backup

#>

param (
        [Alias('p')]
        [string] $ProjectName = 'codedx-docker',
        [string] $AppDataVolumeName = "$ProjectName`_codedx-appdata-volume",
        [string] $DbDataVolumeName = "$ProjectName`_codedx-database-volume",
        [string] $CodeDxTomcatServiceName = "codedx-tomcat",
        [string] $CodeDxDbServiceName = "codedx-db",
        [string] $ComposeConfigPath = $(Resolve-Path "$PSScriptRoot\..\docker-compose.yml").Path,
        [string] $BackupName
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

. $PSScriptRoot/common.ps1

$TomcatContainerName = "$ProjectName`_$CodeDxTomcatServiceName`_1"
$DbContainerName = "$ProjectName`_$CodeDxDbServiceName`_1"
$TomcatImage = Get-TomcatImage $ComposeConfigPath

# Custom prompt for obtaining BackupName, otherwise, would have set it as required in the params
if (!$PSBoundParameters.ContainsKey('BackupName')) {
    $BackupName = Get-BackupName
}

# If the volume is missing the archive file, then it was likely created with the external db flag
$UsingExternalDb = !(Test-Archive $BackupName $DbDataArchiveName)

function Test-Archive([string] $BackupName, [string] $ArchiveName) {
    [bool]$Result = docker run -u 0 --rm -v "$CodeDxBackupVolume`:/backup" $TomcatImage bash -c "
        cd '/backup/$BackupName' &&
        if [ -f $ArchiveName ]; then
            echo 1
        else
            echo 0
        fi
    "
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to test existence of the archive $ArchiveName in $BackupName"
    }
    $Result
}

function Test-BackupExists([string] $BackupName) {
    $Result = docker run --rm -v $CodeDxBackupVolume`:/backup $TomcatImage bash -c "
        cd /backup &&
        if [ -d `"$BackupName`" ]; then
            echo 1
        else
            echo 0
        fi
    "
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to test the existence of backup $BackupName"
    }
    # The return code from the bash command will be interpreted as a string by pwsh
    [System.Convert]::ToBoolean([int]$Result)
}

function Test-Backup([string] $BackupName) {
    (Test-Archive $BackupName $AppDataArchiveName) -or (Test-Archive $BackupName $DbDataVolumeName)
}

function Get-Backups {
    $Result = docker run -u 0 --rm -v "$CodeDxBackupVolume`:/backup" $TomcatImage bash -c "
        cd /backup &&
        ls
    "
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to list backups in volume $CodeDxBackupVolume"
    }
    $Result
}

function Get-BackupName {
    Write-Host "$(Get-Backups)"
    $BackupChoice = Read-Host -Prompt "Choose from the backups above"
    $BackupChoice.Trim()
}

function Restore-BackupVolume([string] $BackupName, [bool] $UsingExternalDb) {
    Write-Verbose "Removing volume $AppDataVolumeName..."
    # Check if the volume exists before deleting it. It's possible a user accidently did `docker-compose down -v` and deleted
    # the associated volumes and is trying to run the restore script. Trying to remove a non-existent volume will be an error.
    (Test-VolumeExists $AppDataVolumeName) -and (docker volume rm $AppDataVolumeName) | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to remove volume $AppDataVolumeName"
    }

    if (!$UsingExternalDb) {
        Write-Verbose "Removing volume $DbDataVolumeName..."
        (Test-VolumeExists $DbDataVolumeName) -and (docker volume rm $DbDataVolumeName) | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to remove volume $DbDataVolumeName"
        }

        Write-Verbose "Copying backup data from $BackupName to volumes $AppDataVolumeName, $DbDataVolumeName..."
        docker run -u 0 --rm -v "$AppDataVolumeName`:/appdata" -v "$DbDataVolumeName`:/dbdata" -v "$CodeDxBackupVolume`:/backup" $TomcatImage bash -c "
            cd '/backup/$BackupName' &&
            tar -C /appdata -xvf $AppDataArchiveName &&
            tar -C /dbdata -xvf $DbDataArchiveName
        "
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to restore volumes $AppDataVolumeName, $DbDataVolumeName"
        }
    }
    else {
        Write-Verbose "Copying backup data from $BackupName to volume $AppDataVolumeName..."
        docker run -u 0 --rm -v "$AppDataVolumeName`:/appdata" -v "$CodeDxBackupVolume`:/backup" $TomcatImage bash -c "
            cd '/backup/$BackupName' &&
            tar -C /appdata -xvf $AppDataArchiveName
        "
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to restore volume $AppDataVolumeName"
        }
        Write-Verbose "Skipping restoring database due to there being no database archive file"
    }
}

Test-Runnable $TomcatContainerName $DbContainerName $AppDataVolumeName $DbDataVolumeName $ComposeConfigPath $TomcatImage

Write-Verbose "Checking Code Dx backups volume $CodeDxBackupVolume and if $BackupName exists..."
if (-not (Test-VolumeExists $CodeDxBackupVolume)) {
    throw "The Code Dx backups volume doesn't exist"
}

if (-not (Test-BackupExists "$BackupName")) {
    throw "The provided backup, $BackupName, does not exist"
}
if (-not (Test-Backup $BackupName)) {
    throw "The provided backup, $BackupName, is not a backup generated by the bundled backup script. Neither $AppDataArchiveName or $DbDataArchiveName could be found"
}

if ($UsingExternalDb) {
    # So long as the user hasn't explicitly set the appdata volume name,
    # update appdata volume name to the default for external database configuration
    if (!$PSBoundParameters.ContainsKey('AppDataVolumeName')) {
        $AppDataVolumeName = "$ProjectName`_codedx-appdata-ex-db-volume"
    }
}

Write-Verbose "Restoring from backup $BackupName..."
Restore-BackupVolume $BackupName $UsingExternalDb

if ($LASTEXITCODE -eq 0) {
    Write-Verbose "Sucessfully restored backup $BackupName"
}
