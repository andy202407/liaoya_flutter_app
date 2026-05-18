@echo off
chcp 65001 >nul 2>&1
title QiaLiao - Android Debug
echo ================================
echo   QiaLiao Android Debug
echo ================================
echo.
cd /d %~dp0
flutter run
echo.
echo Press any key to exit...
pause >nul
