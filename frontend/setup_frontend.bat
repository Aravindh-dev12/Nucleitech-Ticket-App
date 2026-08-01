@echo off
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter is not installed or is not in PATH.
  exit /b 1
)

flutter create --platforms=android,ios,web,windows .
if errorlevel 1 exit /b 1

flutter pub get
if errorlevel 1 exit /b 1

echo Frontend platform folders are ready.
echo Set apiBaseUrl in lib\config.dart, then run: flutter run
