@echo off
chcp 65001 >nul
setlocal

echo ========================================
echo   洽聊 Android Release 构建脚本
echo ========================================
echo.

:: 设置版本号（可修改）
set VERSION_NAME=2.0.0
set VERSION_CODE=2

:: 更新 pubspec.yaml 中的版本号
echo [1/4] 更新版本号: %VERSION_NAME%+%VERSION_CODE%
powershell -Command "(Get-Content pubspec.yaml) -replace 'version: .+', 'version: %VERSION_NAME%+%VERSION_CODE%' | Set-Content pubspec.yaml"

:: 清理旧构建
echo [2/4] 清理旧构建...
call flutter clean

:: 获取依赖
echo [3/4] 获取依赖...
call flutter pub get

:: 构建 Release APK
echo [4/4] 构建 Release APK...
call flutter build apk --release

if %errorlevel% neq 0 (
    echo.
    echo ❌ 构建失败！
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ 构建成功！
echo    版本: v%VERSION_NAME% (build %VERSION_CODE%)
echo    输出: build\app\outputs\flutter-apk\app-release.apk
echo ========================================

:: 复制到项目根目录方便取用
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "app-v%VERSION_NAME%.apk" >nul 2>&1
if %errorlevel% equ 0 (
    echo    副本: app-v%VERSION_NAME%.apk
)

echo.
pause
