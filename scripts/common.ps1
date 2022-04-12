# The archive files the backup procedure will create and the restore procedure will refer to
$AppDataArchiveName = "appdata-backup.tar.gz"
$DbDataArchiveName = "db-backup.tar.gz"
$CodeDxBackupVolume = "codedx-backups"

function Test-RunningContainer([string] $ContainerName) {
    $Result = [bool] (docker container ls | Select-String -Quiet $ContainerName)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to test if the container $ContainerName is running"
    }
    $Result
}

function Test-UsingExternalDb([string] $DockerComposeFilePath) {
    if (Test-Path $DockerComposeFilePath -PathType Leaf) {
        !(Select-String -Quiet -Path $DockerComposeFilePath -Pattern "codedx-db:")
    }
    else {
        throw "The file path provided does not exist: $DockerComposeFilePath"
    }
}

function Test-IsCore {
	$PSVersionTable.PSEdition -eq 'Core'
}

function Get-TomcatImage([string] $DockerComposeFilePath) {
    if (Test-Path $DockerComposeFilePath -PathType Leaf) {
        $TomcatImageLine = Select-String -Path $DockerComposeFilePath -Pattern "^\s*image:.*codedx-tomcat" -Raw
        $TomcatImage = $TomcatImageLine.Split("image:")[1]?.Trim()
        if ([String]::IsNullOrEmpty($TomcatImage)) {
            throw "The Code Dx Tomcat image could not be found in $DockerComposeFilePath"
        }
        $TomcatImage
    }
    else {
        throw "The file path provided does not exist: $DockerComposeFilePath"
    }
}

function Test-AppCommandPath([string] $CommandName) {
	$Command = Get-Command $CommandName -Type Application -ErrorAction SilentlyContinue
	if ($null -eq $Command) {
		return $null
	}
	$Command.Path
}

function Test-VolumeExists([string] $VolumeName) {
    $Result = [bool] (docker volume ls | Select-String -Quiet $VolumeName)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to test the existence of volume $VolumeName"
    }
    $Result
}

function Test-ImageExists([string] $ImageName) {
    [bool] $ImageExists = $(docker images --filter=reference=$ImageName).Split('\n').Length -gt 1
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to test the existence of image $ImageName"
    }
    $ImageExists
}

function Test-Runnable(
    [string] $TomcatContainerName,
    [string] $DbContainerName,
    [string] $AppDataVolumeName,
    [string] $DbDataVolumeName,
    [string] $ComposeConfigPath,
    [string] $BashCapableImage
) {
    Write-Verbose 'Checking if running PowerShell Core...'
    if (-not (Test-IsCore)) {
        throw 'Unable to continue because you must run this script with PowerShell Core (pwsh)'
    }

    Write-Verbose 'Checking PATH prerequisites...'
    'docker','docker-compose' | ForEach-Object {

        if (-not (Test-AppCommandPath $_)) {
            throw "Unable to continue because $_ could not be found. Is $_ installed and included in your PATH?"
        }
    }

    Write-Verbose "Checking for existence of Docker Compose config file: $ComposeConfigPath"
    if (-not (Test-Path $ComposeConfigPath -PathType Leaf)) {
        throw "The following Docker Compose file doesn't exist: $ComposeConfigPath"
    }

    Write-Verbose 'Checking containers aren''t running...'
    [string[]] $RunningContainers = @()
    "$TomcatContainerName","$DbContainerName" | ForEach-Object {

        if (Test-RunningContainer $_) {
            $RunningContainers += $_
        }
    }
    if ($RunningContainers.Count -gt 0) {
        throw "Unable to continue because backup/restore requires the container(s) $([String]::Join(', ', $RunningContainers)) to be stopped. This may be done with 'docker container stop $([String]::Join(' ', $RunningContainers))' or 'docker-compose -f $($ComposeConfigPath) down'"
    }

    Write-Verbose 'Checking if operations can be performed on volumes...'
    if ($BashCapableImage -ne (Get-TomcatImage $ComposeConfigPath)) {
        if (-not (Test-ImageExists $BashCapableImage)) {
            throw "The provided image $BashCapableImage doesn't exist"
        }
    }


}