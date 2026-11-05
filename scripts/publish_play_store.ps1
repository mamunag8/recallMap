# RecallMap 1-Command Google Play Store Keystore & Release Builder (Windows PowerShell)
$ErrorActionPreference = "Stop"

Write-Host "=== RecallMap: FSRS & PDF Study (com.recallmap.app) Play Store Publisher ===" -ForegroundColor Cyan

$keystoreDir = Join-Path $PSScriptRoot "..\android\app"
$keystorePath = Join-Path $keystoreDir "recallmap-upload-keystore.jks"
$keyPropsPath = Join-Path $PSScriptRoot "..\android\key.properties"

$storePass = "RecallMapStore2026!"
$keyAlias  = "recallmap_upload"

if (-not (Test-Path $keystorePath)) {
    Write-Host "[1/3] Generating 2048-bit RSA Upload Keystore for Google Play App Signing..." -ForegroundColor Yellow
    keytool -genkey -v `
        -keystore $keystorePath `
        -alias $keyAlias `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -storepass $storePass `
        -keypass $storePass `
        -dname "CN=RecallMap Studio, OU=Education, O=Kasb LLC, L=Dhaka, S=Dhaka, C=BD"
} else {
    Write-Host "[1/3] Existing Upload Keystore found at $keystorePath" -ForegroundColor Green
}

Write-Host "[2/3] Writing android/key.properties..." -ForegroundColor Yellow
@"
storePassword=$storePass
keyPassword=$storePass
keyAlias=$keyAlias
storeFile=recallmap-upload-keystore.jks
"@ | Set-Content -Path $keyPropsPath -Encoding UTF8

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Host "[3/3] Building Signed Google Play Store Android App Bundle (app-release.aab)..." -ForegroundColor Green
    flutter pub get
    flutter build appbundle --release
    Write-Host "SUCCESS! Upload build\app\outputs\bundle\release\app-release.aab to Google Play Console." -ForegroundColor Green
} else {
    Write-Host "[3/3] Local Flutter CLI not detected on PATH." -ForegroundColor Yellow
    Write-Host "Your signed Play Store .aab & .apk are built automatically via GitHub Actions at:" -ForegroundColor Cyan
    Write-Host "https://github.com/mamunag8/recallMap/actions" -ForegroundColor Cyan
}
