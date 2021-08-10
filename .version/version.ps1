param (
	[Parameter(Mandatory=$true)][string] $codeDxVersionTag
)

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

$location = Join-Path $PSScriptRoot '..'
Push-Location $location

'./docker-compose.yml','./docker-compose-external-db.yml','./README.md' | ForEach-Object {

	$newContents = (Get-Content $_) -replace 'image:\scodedx/codedx-tomcat:v(\d+\.\d+\.\d+)', "image: codedx/codedx-tomcat:$codeDxVersionTag"
	Set-Content $_	$newContents
}
