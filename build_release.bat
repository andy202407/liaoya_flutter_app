@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

echo ========================================
echo   QiaLiao Android Release Build
echo ========================================
echo.

:: Version config
set VERSION_NAME=2.0.0
set VERSION_CODE=2

:: Update version in pubspec.yaml
echo [1/4] Update version: %VERSION_NAME%+%VERSION_CODE%
powershell -Command "(Get-Content pubspec.yaml) -replace 'version: .+', 'version: %VERSION_NAME%+%VERSION_CODE%' | Set-Content pubspec.yaml -Encoding UTF8"

:: Clean
echo [2/4] Clean...
call flutter clean

:: Get dependencies
echo [3/4] Get dependencies...
call flutter pub get

:: Build Release APK
echo [4/4] Build Release APK...
call flutter build apk --release

if %errorlevel% neq 0 (
    echo.
    echo [FAILED] Build failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo [SUCCESS] Build complete!
echo    Version: v%VERSION_NAME% (build %VERSION_CODE%)
echo    Output: build\app\outputs\flutter-apk\app-release.apk
echo ========================================

:: Copy to root for easy access
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "app-v%VERSION_NAME%.apk" >nul 2>&1
if %errorlevel% equ 0 (
    echo    Copy: app-v%VERSION_NAME%.apk
)

echo.
pause
