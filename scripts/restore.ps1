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
        [string] $backupVolumeName
)

$appDataArchiveName = "appdata-backup.tar"
$dbDataArchiveName = "db-backup.tar"

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

Write-Verbose "Restoring Backup Volume $backupVolumeName"
Restore-Backup-Volume($backupVolumeName)

if ($LASTEXITCODE -eq 0) {
    Write-Verbose "Restoring Backup Volume $backupVolumeName successful"
}