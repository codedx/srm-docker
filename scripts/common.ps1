# The archive files the backup procedure will create and the restore procedure will refer to
$AppDataArchiveName = "appdata-backup.tar"
$DbDataArchiveName = "db-backup.tar"

function Test-RunningContainer([string] $ContainerName) {
	docker container ls | grep $ContainerName | Out-Null
	$LASTEXITCODE -eq 0
}

function Test-AppCommandPath([string] $CommandName) {

	$Command = Get-Command $CommandName -Type Application -ErrorAction SilentlyContinue
	if ($null -eq $Command) {
		return $null
	}
	$Command.Path
}

function Test-Volume-Exists([string] $VolumeName) {
    docker volume ls | grep $VolumeName >$null
    $LASTEXITCODE -eq 0
}

function Test-Script-Can-Run([string] $TomcatContainerName, [string] $DbContainerName) {
    Write-Verbose 'Checking PATH prerequisites...'
    'docker','docker-compose' | ForEach-Object {

        if (-not (Test-AppCommandPath $_)) {
            throw "Unable to continue because $_ could not be found. Is $_ installed and included in your PATH?"
        }
    }

    Write-Verbose 'Checking containers aren''t running...'
    "$TomcatContainerName","$DbContainerName" | ForEach-Object {

        if (Test-RunningContainer $_) {
            throw "Unable to continue because a backup cannot be created while the container $_ is running. Either stop the container with 'docker container stop $_' or 'docker-compose down'"
        }
    }
}