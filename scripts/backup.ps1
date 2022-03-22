<#PSScriptInfo
.VERSION 1.0.0
.GUID 5eadc648-e218-48d9-b264-f96f01f81434
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

.PARAMETER RetainPeriod
By default backups are set for removal after 30 days. Where those expired backups are removed from the Code Dx backup volume the next
time the backup script is run.

The value supports number of days, hours, and minutes. It follows the format { [d.]hh:mm }, where 10 days is simply "10", 10.5 days is
"10.12:00", and only 5 hours is "05:00".

.PARAMETER SkipConfirmation
When present, any prompts for user confirmation will be skipped and the program will resume

.PARAMETER BackupDirectoryName
The name of the directory the backup will be stored under in the Code Dx backup volume.

If not specified, an auto generated backup name will be used following the format of "backup-{date}-{time}"

.LINK
https://github.com/codedx/codedx-docker#creating-a-backup

#>

param (
        [Alias('p')]
        [string] $ProjectName = 'codedx-docker',
        [string] $AppDataVolumeName = "$ProjectName`_codedx-appdata-volume",
        [string] $DbDataVolumeName = "$ProjectName`_codedx-database-volume",
        [string] $CodeDxTomcatServiceName = "codedx-tomcat",
        [string] $CodeDxDbServiceName = "codedx-db",
        [string] $ComposeConfigPath = $(Resolve-Path "$PSScriptRoot\..\docker-compose.yml").Path,
        [string] $RetainPeriod = "30",
        [switch] $SkipConfirmation,
        [string] $BackupDirectoryName = "backup-$([System.DateTime]::Now.ToString("yyyyMMdd-HHmmss"))"
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

. $PSScriptRoot/common.ps1

$TomcatContainerName = "$ProjectName`_$CodeDxTomcatServiceName`_1"
$DbContainerName = "$ProjectName`_$CodeDxDbServiceName`_1"
$BashCapableImage = Get-TomcatImage $ComposeConfigPath
$UsingExternalDb = Test-UsingExternalDb $ComposeConfigPath
$RetainTimeSpan = $RetainPeriod -eq "0" ? [TimeSpan]::MaxValue : [TimeSpan]::Parse($RetainPeriod)

function Test-BackupExists([string] $BackupName) {
    $Result = docker run --rm -v $CodeDxBackupVolume`:/backup $BashCapableImage bash -c "
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

function Get-BackupConfirmation([string] $BackupName) {
    if (Test-BackupExists $BackupName) {
        if (!$SkipConfirmation) {
            $continueAnswer = Read-Host -Prompt "A backup with the name $BackupName already exists, continuing will overwrite this backup. Continue? (y/n)"
            if (-not ($continueAnswer -eq "y" -or $continueAnswer -eq "yes")) {
                Exit 0
            }
        }
        # Indicates the user has chosen to overwrite an existing backup
        1
    }
    else {
        # Backup doesn't already exist
        0
    }
}

function Test-VolumeAppData([string] $VolumeName) {
    if (Test-VolumeExists $VolumeName) {
        $Result = docker run -u 0 --rm -v "$VolumeName`:/appdata" $BashCapableImage bash -c "
        cd /appdata &&
        if [ -f codedx.props ] && [ -f logback.xml ]; then
            echo 1
        else
            echo 0
        fi"
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to test the existence of appdata in $VolumeName"
        }
        [System.Convert]::ToBoolean([int]$Result)
    }
    else {
        $false
    }
}

function Test-VolumeDatabase([string] $VolumeName) {
    if (Test-VolumeExists $VolumeName) {
        $Result = docker run -u 0 --rm -v "$VolumeName`:/db" $BashCapableImage bash -c "
        cd /db &&
        if [ -d 'data' ] && [ -d 'data/mysql' ]; then
            echo 1
        else
            echo 0
        fi"
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to test the existence of database data in $VolumeName"
        }
        [System.Convert]::ToBoolean([int]$Result)
    }
    else {
        $false
    }
}

function Remove-OldBackups([TimeSpan] $RetainDuration) {
    # TODO, this isn't proceeding after throwing the error despite 'continue' being set
    # on error action preference
    $Local:ErrorActionPreference = 'Continue'
    docker run -u 0 --rm -v $CodeDxBackupVolume`:/backup $BashCapableImage bash -c "
        cd /usr/local/tomcat/bin/ &&
        ./clean-backups.sh $($RetainDuration.Days) $($RetainDuration.Hours) $($RetainDuration.Minutes) /backup
    "
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to check if existing backups exceeded the retain period of $RetainPeriod days"
    }
}

function New-Backup([string] $BackupName, [bool] $ExplicitBackupName) {
    $OverwriteBackup = $false

    if ($ExplicitBackupName) {
        Write-Verbose "Checking if $BackupName already exists..."
        $OverwriteBackup = Get-BackupConfirmation $BackupName
    }

    if ($OverwriteBackup) {
        Write-Verbose "User has chosen to overwrite existing backup $BackupName, overwriting..."
        docker run -u 0 --rm -v "$CodeDxBackupVolume`:/backup" $BashCapableImage bash -c "rm -f `"/backup/$BackupName/*.tar.gz`""
        if ($LASTEXITCODE -ne 0) {
			throw "Unable to delete contents of $BackupName for overwrite"
		}
    }
    else {
        docker run -u 0 --rm -v "$CodeDxBackupVolume`:/backup" $BashCapableImage bash -c "
            cd /backup &&
            mkdir -p $BackupName
        "
        if ($LASTEXITCODE -ne 0) {
			throw "Unable to create backup directory $BackupName in $CodeDxBackupVolume"
		}
    }

    Write-Verbose "Creating backup of appdata volume, $AppDataVolumeName..."
    # Create backup of appdata. tar -C is used to set the location for the archive, by doing this we don't store parent directories containing
    # our desired folder. Instead, it's just the contents of the volume in the archive.
    docker run -u 0 --rm -v "$CodeDxBackupVolume`:/backup" -v "$AppDataVolumeName`:/appdata" $BashCapableImage bash -c "tar -C /appdata -cvzf '/backup/$BackupName/$AppDataArchiveName' ."
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to backup appdata volume $AppDataVolumeName"
    }
    # Create backup of DB if it's being used according to the -UsingExternalDb switch
    if (!$UsingExternalDb) {
        Write-Verbose "Creating backup of DB volume, $DbDataVolumeName..."
        docker run -u 0 --rm -v "$CodeDxBackupVolume`:/backup" -v "$DbDataVolumeName`:/dbdata" $BashCapableImage bash -c "tar -C /dbdata -cvzf '/backup/$BackupName/$DbDataArchiveName' ."
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to backup database volume $DbDataVolumeName"
        }
    }
    else {
        Write-Verbose 'Skipping backing up database due to external database being used'
    }
}

Test-Runnable $TomcatContainerName $DbContainerName $AppDataVolumeName $DbDataVolumeName $ComposeConfigPath $BashCapableImage

Write-Verbose "Checking $AppDataVolumeName is a valid Code Dx appdata volume"
if (-not (Test-VolumeAppData $AppDataVolumeName)) {
    throw "The provided appdata volume $AppDataVolumeName does not appear to be Code Dx appdata. Example missing files include codedx.props and logback.xml."
}
if (!$UsingExternalDb) {
    Write-Verbose "Checking $DbDataVolumeName is a valid Code Dx database volume"
    if (-not (Test-VolumeDatabase $DbDataVolumeName)) {
        throw "The provided database volume $DbDataVolumeName does not appear to be a Code Dx database. Failed to locate system databases such as mysql."
    }
}

Write-Verbose "Checking if any backups are older than the retain period of $($RetainTimeSpan.TotalDays) days..."
Remove-OldBackups $RetainTimeSpan

Write-Verbose "Creating Backup $BackupDirectoryName..."
New-Backup "$BackupDirectoryName" $PSBoundParameters.ContainsKey('BackupDirectoryName')

if ($LASTEXITCODE -eq 0) {
    Write-Verbose "Successfully created backup $BackupDirectoryName"
}
