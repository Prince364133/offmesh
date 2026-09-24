# NearLink Windows Build Script
# Builds and tests the transport-independent core with OpenJDK 17+.
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "Cleaning build directory..." -ForegroundColor Cyan
if (Test-Path build) {
    Remove-Item -Recurse -Force build
}
New-Item -ItemType Directory -Path build\core, build\test -Force | Out-Null

Write-Host "Compiling core sources..." -ForegroundColor Cyan
$coreFiles = (Get-ChildItem -Path core\src -Filter *.java -Recurse).FullName
javac -Xlint:all --release 17 -d build\core $coreFiles

Write-Host "Compiling test sources..." -ForegroundColor Cyan
$testFiles = (Get-ChildItem -Path core\test -Filter *.java -Recurse).FullName
javac --release 17 -cp build\core -d build\test $testFiles

Write-Host "Running 22-case test suite..." -ForegroundColor Cyan
java -cp "build\core;build\test" net.nearlink.core.Tests

Write-Host "All tests executed successfully!" -ForegroundColor Green
