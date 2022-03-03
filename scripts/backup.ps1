<#PSScriptInfo
.VERSION 1.0.0
.GUID a56b7e15-a300-4da7-85b6-8c3bdff8d897
.AUTHOR Code Dx
#>

<#
.SYNOPSIS
Creates a backup volume for the data in a Code Dx Docker Compose install

.DESCRIPTION
This script creates a backup of the appdata and database volumes created automatically
by a Code Dx docker-compose install. These backups can then be used by a restore script.

.PARAMETER ProjectName
The name used for prefacing volume and container names.

The project name is used by docker-compose and preceeds the name of docker resources
such as containers and volumes. By default, this is set to the name of the
containing directory of the compose file.

If you have multiple Code Dx Docker Compose installations, you should specify the project name to refer
to a specific one.

By default, this is 'codedx-docker'.

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
The name of the backup volume generated by this script. The generated volume will be referenced
by this name when restoring from it.

.LINK
https://github.com/codedx/codedx-docker#creating-a-backup

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

function Get-Backup-Confirmation([string] $BackupName) {
    docker volume ls | grep $BackupName | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $continueAnswer = Read-Host -Prompt "A backup volume with the name $BackupName already exists, continuing will overwrite this backup. Continue? (y/n)"
        # Do a case insensitive string equality check to see if the user wants to proceed else exit
        if (-not ($continueAnswer -ieq "y" -or $continueAnswer -ieq "yes")) {
            Exit 0
        }
        # Indicates the user has chosen to overwrite an existing backup
        1
    }
    else {
        # Backup doesn't already exist
        0
    }
}

function Test-Volume-Is-AppData([string] $VolumeName) {
    if (Test-Volume-Exists $VolumeName) {
        [bool]$Result = docker run --rm -v $VolumeName`:/appdata ubuntu bash -c "
        cd /appdata &&
        ls &&
        if [ -f codedx.props ] && [ -f logback.xml ]; then
            echo 1
        else
            echo 0
        fi"
        echo $Result
        $Result
    }
    else {
        $false
    }
}

function Test-Volume-Is-Database([string] $VolumeName) {
    if (Test-Volume-Exists $VolumeName) {
        [bool]$Result = docker run --rm -v $VolumeName`:/db ubuntu bash -c "
        cd /db &&
        if [ -d 'data' ] && [ -d 'data/mysql' ]; then
            echo 1
        else
            echo 0
        fi"
        $Result
    }
    else {
        $false
    }
}

function New-Backup-Volume([string] $BackupName) {
    $OverwriteBackup = Get-Backup-Confirmation $BackupName

    if ($OverwriteBackup) {
        Write-Verbose "User has chosen to overwrite existing backup volume $BackupName, overwriting..."
        docker run --rm -v $BackupName`:/backup ubuntu bash -c "rm /backup/*.tar"
    }

    Write-Verbose "Creating backup of appdata volume, $AppDataVolumeName..."
    # Create backup of appdata. tar -C is used to set the location for the archive, by doing this we don't store parent directories containing
    # our desired folder. Instead, it's just the contents of the volume in the archive.
    docker run --rm -v $BackupName`:/backup -v $AppDataVolumeName`:/appdata ubuntu tar -C /appdata -cvf /backup/$AppDataArchiveName .
    # Create backup of DB if it's being used according to the -UsingExternalDb switch
    if (!$UsingExternalDb) {
        Write-Verbose "Creating backup of DB volume, $DbDataVolumeName..."
        docker run --rm -v $BackupName`:/backup -v $DbDataVolumeName`:/dbdata ubuntu tar -C /dbdata -cvf /backup/$DbDataArchiveName .
    }
    else {
        Write-Verbose 'Skipping backing up database due to -UsingExternalDb being true'
    }
}

Test-Script-Can-Run $TomcatContainerName $DbContainerName

Write-Verbose "Checking $AppDataVolumeName is a valid Code Dx appdata volume"
if (-not (Test-Volume-Is-AppData $AppDataVolumeName)) {
    throw "The provided appdata volume $AppDataVolumeName does not appear to be Code Dx appdata. Example missing files include codedx.props and logback.xml."
}
if (!$UsingExternalDb) {
    Write-Verbose "Checking $DbDataVolumeName is a valid Code Dx database volume"
    if (-not (Test-Volume-Is-Database $DbDataVolumeName)) {
        throw "The provided database volume $DbDataVolumeName does not appear to be a Code Dx database. Failed to locate system databases such as mysql."
    }
}

Write-Verbose "Creating Backup Volume $BackupVolumeName..."
New-Backup-Volume $BackupVolumeName
Write-Verbose "Successfully created backup volume $BackupVolumeName"
