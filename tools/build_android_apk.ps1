param(
  [string]$ApiBaseUrl = "http://161.97.87.75/ticket/api.php",
  [switch]$BootstrapToolchain
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$FrontendDir = Join-Path $RepoRoot "frontend"
$ToolchainDir = Join-Path $RepoRoot ".local-toolchain"
$DownloadsDir = Join-Path $ToolchainDir "downloads"
$FlutterDir = Join-Path $ToolchainDir "flutter"
$JdkDir = Join-Path $ToolchainDir "jdk17"
$AndroidSdkDir = Join-Path $ToolchainDir "android-sdk"
$PubCacheDir = Join-Path $ToolchainDir "pub-cache"
$GradleHomeDir = Join-Path $ToolchainDir "gradle-home"
$AndroidUserHomeDir = Join-Path $ToolchainDir "android-user-home"
$DistDir = Join-Path $RepoRoot "dist"

Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-Directory {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Resolve-UnderToolchain {
  param([string]$Path)
  $root = [System.IO.Path]::GetFullPath($ToolchainDir)
  $target = [System.IO.Path]::GetFullPath($Path)
  if (-not $target.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to modify path outside toolchain directory: $target"
  }
  return $target
}

function Remove-ToolchainPath {
  param([string]$Path)
  if (Test-Path -LiteralPath $Path) {
    $safePath = Resolve-UnderToolchain $Path
    Remove-Item -LiteralPath $safePath -Recurse -Force
  }
}

function Download-File {
  param(
    [string]$Url,
    [string]$OutputPath
  )

  if (Test-Path -LiteralPath $OutputPath) {
    if ([System.IO.Path]::GetExtension($OutputPath) -eq ".zip") {
      try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($OutputPath)
        $zip.Dispose()
      } catch {
        Write-Host "Removing incomplete ZIP: $OutputPath"
        Remove-ToolchainPath $OutputPath
      }
    }
  }

  if (Test-Path -LiteralPath $OutputPath) {
    Write-Host "Using cached download: $OutputPath"
    return
  }

  $partialPath = "$OutputPath.part"
  Write-Host "Downloading $Url"

  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  if ($curl) {
    & $curl.Source `
      --location `
      --fail `
      --retry 8 `
      --retry-all-errors `
      --retry-delay 5 `
      --speed-limit 1024 `
      --speed-time 60 `
      --continue-at - `
      --output $partialPath `
      $Url

    if ($LASTEXITCODE -ne 0) {
      throw "curl failed with exit code $LASTEXITCODE while downloading $Url"
    }
  } else {
    if (Test-Path -LiteralPath $partialPath) {
      Remove-ToolchainPath $partialPath
    }
    Invoke-WebRequest -Uri $Url -OutFile $partialPath -UseBasicParsing
  }

  if ([System.IO.Path]::GetExtension($OutputPath) -eq ".zip") {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($partialPath)
    $zip.Dispose()
  }

  Move-Item -LiteralPath $partialPath -Destination $OutputPath -Force
}

function Expand-ZipFile {
  param(
    [string]$ZipPath,
    [string]$DestinationPath
  )

  New-Directory $DestinationPath
  $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
  if ($tar) {
    & $tar.Source -xf $ZipPath -C $DestinationPath
    if ($LASTEXITCODE -ne 0) {
      throw "tar failed with exit code $LASTEXITCODE while extracting $ZipPath"
    }
  } else {
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $DestinationPath -Force
  }
}

function Get-FlutterCommand {
  $localFlutter = Join-Path $FlutterDir "bin\flutter.bat"
  if (Test-Path -LiteralPath $localFlutter) {
    return $localFlutter
  }

  $pathFlutter = Get-Command flutter -ErrorAction SilentlyContinue
  if ($pathFlutter) {
    return $pathFlutter.Source
  }

  return $null
}

function Install-Jdk {
  $javaExe = Join-Path $JdkDir "bin\java.exe"
  if (Test-Path -LiteralPath $javaExe) {
    return
  }

  New-Directory $DownloadsDir
  $zipPath = Join-Path $DownloadsDir "temurin-jdk17-windows-x64.zip"
  $extractDir = Join-Path $ToolchainDir "jdk-extract"

  Download-File `
    "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk" `
    $zipPath

  Remove-ToolchainPath $extractDir
  Expand-ZipFile $zipPath $extractDir
  $jdkRoot = Get-ChildItem -LiteralPath $extractDir -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "bin\java.exe") } |
    Select-Object -First 1

  if (-not $jdkRoot) {
    throw "Downloaded JDK archive did not contain bin\java.exe."
  }

  Remove-ToolchainPath $JdkDir
  Move-Item -LiteralPath $jdkRoot.FullName -Destination $JdkDir
  Remove-ToolchainPath $extractDir
}

function Install-Flutter {
  $flutterBat = Join-Path $FlutterDir "bin\flutter.bat"
  if (Test-Path -LiteralPath $flutterBat) {
    return
  }

  New-Directory $DownloadsDir
  $releaseJsonPath = Join-Path $DownloadsDir "flutter-releases-windows.json"
  $zipPath = Join-Path $DownloadsDir "flutter-windows-stable.zip"
  $extractDir = Join-Path $ToolchainDir "flutter-extract"

  Download-File `
    "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json" `
    $releaseJsonPath

  $metadata = Get-Content -Raw -LiteralPath $releaseJsonPath | ConvertFrom-Json
  $stableHash = $metadata.current_release.stable
  $stableRelease = $metadata.releases |
    Where-Object { $_.hash -eq $stableHash } |
    Select-Object -First 1

  if (-not $stableRelease) {
    throw "Could not find the current Flutter stable release in releases_windows.json."
  }

  $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/$($stableRelease.archive)"
  Download-File $flutterUrl $zipPath

  Remove-ToolchainPath $extractDir
  Expand-ZipFile $zipPath $extractDir
  $expandedFlutter = Join-Path $extractDir "flutter"
  if (-not (Test-Path -LiteralPath (Join-Path $expandedFlutter "bin\flutter.bat"))) {
    throw "Downloaded Flutter archive did not contain bin\flutter.bat."
  }

  Remove-ToolchainPath $FlutterDir
  Move-Item -LiteralPath $expandedFlutter -Destination $FlutterDir
  Remove-ToolchainPath $extractDir
}

function Install-AndroidSdk {
  $sdkManager = Join-Path $AndroidSdkDir "cmdline-tools\latest\bin\sdkmanager.bat"
  if (-not (Test-Path -LiteralPath $sdkManager)) {
    New-Directory $DownloadsDir
    $zipPath = Join-Path $DownloadsDir "android-commandlinetools-windows.zip"
    $extractDir = Join-Path $ToolchainDir "android-cmdline-extract"
    $latestDir = Join-Path $AndroidSdkDir "cmdline-tools\latest"

    Download-File `
      "https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip" `
      $zipPath

    Remove-ToolchainPath $extractDir
    Expand-ZipFile $zipPath $extractDir
    $cmdlineTools = Join-Path $extractDir "cmdline-tools"
    if (-not (Test-Path -LiteralPath (Join-Path $cmdlineTools "bin\sdkmanager.bat"))) {
      throw "Downloaded Android command-line tools did not contain bin\sdkmanager.bat."
    }

    New-Directory (Join-Path $AndroidSdkDir "cmdline-tools")
    Remove-ToolchainPath $latestDir
    Move-Item -LiteralPath $cmdlineTools -Destination $latestDir
    Remove-ToolchainPath $extractDir
  }

  Write-Host "Accepting Android SDK licenses"
  $yesInput = ("y" + [Environment]::NewLine) * 200
  $yesInput | & $sdkManager "--sdk_root=$AndroidSdkDir" --licenses | Out-Host

  Write-Host "Reading Android SDK package list"
  $packageList = & $sdkManager "--sdk_root=$AndroidSdkDir" --list

  $platforms = @()
  $buildTools = @()
  foreach ($line in $packageList) {
    if ($line -match "^\s*platforms;android-(\d+)\s*\|") {
      $platforms += [int]$Matches[1]
    }
    if ($line -match "^\s*build-tools;([0-9]+(?:\.[0-9]+)+)\s*\|") {
      $buildTools += $Matches[1]
    }
  }

  if ($platforms.Count -eq 0 -or $buildTools.Count -eq 0) {
    throw "Could not read Android SDK package list."
  }

  $apiLevel = $platforms | Sort-Object -Descending | Select-Object -First 1
  $buildToolsVersion = $buildTools |
    Sort-Object { [version]$_ } -Descending |
    Select-Object -First 1

  Write-Host "Installing Android SDK platform android-$apiLevel and build-tools $buildToolsVersion"
  & $sdkManager `
    "--sdk_root=$AndroidSdkDir" `
    "platform-tools" `
    "platforms;android-$apiLevel" `
    "build-tools;$buildToolsVersion" | Out-Host
}

function Set-BuildEnvironment {
  if (Test-Path -LiteralPath (Join-Path $JdkDir "bin\java.exe")) {
    $env:JAVA_HOME = $JdkDir
  }
  $env:ANDROID_HOME = $AndroidSdkDir
  $env:ANDROID_SDK_ROOT = $AndroidSdkDir
  $env:ANDROID_USER_HOME = $AndroidUserHomeDir
  $env:PUB_CACHE = $PubCacheDir
  $env:GRADLE_USER_HOME = $GradleHomeDir

  $existingPathParts = @()
  if ($env:Path) {
    $existingPathParts = $env:Path -split ";"
  }

  $pathParts = @(
    (Join-Path $FlutterDir "bin"),
    (Join-Path $JdkDir "bin"),
    (Join-Path $AndroidSdkDir "platform-tools"),
    (Join-Path $AndroidSdkDir "cmdline-tools\latest\bin")
  ) + $existingPathParts

  $env:Path = ($pathParts |
    Where-Object { $_ -and (Test-Path -LiteralPath $_ -ErrorAction SilentlyContinue) } |
    Select-Object -Unique) -join ";"
}

function Ensure-AndroidManifest {
  $manifestPath = Join-Path $FrontendDir "android\app\src\main\AndroidManifest.xml"
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "AndroidManifest.xml was not generated."
  }

  [xml]$manifest = Get-Content -Raw -LiteralPath $manifestPath
  $androidNs = "http://schemas.android.com/apk/res/android"
  $manifestNode = $manifest.manifest

  foreach ($permissionName in @("android.permission.INTERNET", "android.permission.CAMERA")) {
    $exists = $false
    foreach ($permission in $manifestNode."uses-permission") {
      if ($permission.GetAttribute("name", $androidNs) -eq $permissionName) {
        $exists = $true
      }
    }

    if (-not $exists) {
      $permission = $manifest.CreateElement("uses-permission")
      $permission.SetAttribute("name", $androidNs, $permissionName)
      $manifestNode.PrependChild($permission) | Out-Null
    }
  }

  $application = $manifestNode.application
  $application.SetAttribute("label", $androidNs, "NUCLEI TECH")
  $application.SetAttribute("usesCleartextTraffic", $androidNs, "true")
  $manifest.Save($manifestPath)
}

function Ensure-GradleSettings {
  $propertiesPath = Join-Path $FrontendDir "android\gradle.properties"
  if (-not (Test-Path -LiteralPath $propertiesPath)) {
    throw "gradle.properties was not generated."
  }

  $settings = [ordered]@{
    "org.gradle.jvmargs" = "-Xmx2G -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError"
    "org.gradle.daemon" = "false"
    "org.gradle.workers.max" = "2"
    "kotlin.daemon.jvmargs" = "-Xmx1024m -XX:MaxMetaspaceSize=512m"
  }

  $lines = [System.Collections.Generic.List[string]]::new()
  $seen = @{}
  foreach ($line in Get-Content -LiteralPath $propertiesPath) {
    $updated = $false
    foreach ($key in $settings.Keys) {
      if ($line -match "^\s*$([regex]::Escape($key))=") {
        $lines.Add("$key=$($settings[$key])")
        $seen[$key] = $true
        $updated = $true
        break
      }
    }

    if (-not $updated) {
      $lines.Add($line)
    }
  }

  foreach ($key in $settings.Keys) {
    if (-not $seen.ContainsKey($key)) {
      $lines.Add("$key=$($settings[$key])")
    }
  }

  Set-Content -LiteralPath $propertiesPath -Value $lines -Encoding ASCII
}

if (-not (Test-Path -LiteralPath $FrontendDir)) {
  throw "Could not find frontend directory: $FrontendDir"
}

New-Directory $ToolchainDir
New-Directory $DownloadsDir
New-Directory $PubCacheDir
New-Directory $GradleHomeDir
New-Directory $AndroidUserHomeDir
New-Directory $DistDir

if ($BootstrapToolchain) {
  Install-Jdk
  Install-Flutter
  Set-BuildEnvironment
  Install-AndroidSdk
}

Set-BuildEnvironment
$flutterCommand = Get-FlutterCommand
if (-not $flutterCommand) {
  throw "Flutter is not installed. Re-run with -BootstrapToolchain to download a local build toolchain."
}

Push-Location $FrontendDir
try {
  & $flutterCommand config --no-analytics | Out-Host
  & $flutterCommand create --platforms=android --org com.nucleitech . | Out-Host
  Ensure-AndroidManifest
  Ensure-GradleSettings
  & $flutterCommand pub get | Out-Host
  & $flutterCommand build apk --release "--dart-define=API_BASE_URL=$ApiBaseUrl" | Out-Host
} finally {
  Pop-Location
}

$apkPath = Join-Path $FrontendDir "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path -LiteralPath $apkPath)) {
  throw "APK build completed without producing app-release.apk."
}

$distApk = Join-Path $DistDir "NUCLEI_TECH.apk"
Copy-Item -LiteralPath $apkPath -Destination $distApk -Force
Write-Host "APK ready: $distApk"
