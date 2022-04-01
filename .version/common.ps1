$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
Set-PSDebug -Strict

function Test-CodeDxVersion([string] $dockerComposePath,
	[string] $codeDxVersionTag,
	[string] $mariaDBVersionTag) {

	$dockerComposeContent = Get-Content $dockerComposePath

	$dockerComposeContent -match "image:\scodedx/codedx-tomcat:v$codeDxVersionTag" -and 
		$dockerComposeContent -match "image:\scodedx/codedx-mariadb:v$mariaDBVersionTag"
}