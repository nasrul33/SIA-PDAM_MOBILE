<#
.SYNOPSIS
  Build & run SIA-PDAM Lapangan di emulator/device dengan env fix mesin ini.

.DESCRIPTION
  Mesin dev ini punya dua kendala environment untuk build Flutter-Android:
    1. Folder Temp user (%LOCALAPPDATA%\Temp) rusak untuk socket AF_UNIX, yang
       dipakai JDK untuk pipe internal Selector.open() → semua proses Java NIO
       (Gradle) gagal "Unable to establish loopback connection".
       Fix: arahkan TEMP/TMP ke folder sehat (D:\tmp).
    2. Pub cache default di drive C: sedangkan proyek di D: → Kotlin incremental
       compiler gagal (beda root drive). Fix: PUB_CACHE di D: + kotlin.incremental=false
       (sudah diset di android/gradle.properties).

  Script ini menyetel semua env yang diperlukan lalu menjalankan flutter run.

.PARAMETER Device
  Target device id (default: emulator-5554).

.EXAMPLE
  ./tool/run.ps1
  ./tool/run.ps1 -Device emulator-5554
#>
param(
  [string]$Device = 'emulator-5554',
  [string]$FlutterBat = 'C:\flutter\bin\flutter.bat'
)

$ErrorActionPreference = 'Stop'

# Folder sehat untuk socket AF_UNIX (lihat .DESCRIPTION).
$env:TEMP = 'D:\tmp'
$env:TMP  = 'D:\tmp'
# Pub cache satu drive dengan proyek.
$env:PUB_CACHE = 'D:\pubcache'
# Toolchain.
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_SDK_ROOT = "$env:LOCALAPPDATA\Android\Sdk"
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT

New-Item -ItemType Directory -Force 'D:\tmp', 'D:\pubcache' | Out-Null

Write-Host "Menjalankan SIA-PDAM Lapangan di $Device ..." -ForegroundColor Cyan
& $FlutterBat run -d $Device --no-version-check
