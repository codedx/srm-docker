param (
	[Parameter(Mandatory=$true)][string] $codeDxVersionTag,
	[Parameter(Mandatory=$true)][string] $mariaDbVersionTag
)

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

$location = Join-Path $PSScriptRoot '..'
Push-Location $location

'./docker-compose.yml','./docker-compose-external-db.yml','./README.md' | ForEach-Object {

	$newContents = (Get-Content $_) -replace 'image:\scodedx/codedx-tomcat:v(\d+\.\d+\.\d+(?:.\d+)?)', "image: codedx/codedx-tomcat:$codeDxVersionTag"
	Set-Content $_	$newContents
}

'./docker-compose.yml' | ForEach-Object {

	$newContents = (Get-Content $_) -replace 'image:\scodedx/codedx-mariadb:v(\d+\.\d+\.\d+(?:.\d+)?)', "image: codedx/codedx-mariadb:$mariaDbVersionTag"
	Set-Content $_	$newContents
}
