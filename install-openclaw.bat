@echo off
chcp 65001 >nul 2>&1
title OpenClaw 一键部署工具
color 0A

echo.
echo  ============================================
echo     OpenClaw 一键部署工具 (Windows)
echo  ============================================
echo.
echo  本脚本将自动完成以下步骤:
echo    1. 检查并安装 Docker Desktop
echo    2. 配置 AI 模型 API Key
echo    3. 下载并启动 OpenClaw
echo.
echo  请确保网络畅通
echo.
pause

:: 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] 需要管理员权限，正在请求提升...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: 检查 Docker
echo.
echo [1/4] 检查 Docker 环境...
docker --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Docker 已安装
    goto :check_docker_running
) else (
    echo [!] 未检测到 Docker，即将安装 Docker Desktop...
    echo [!] 安装完成后需要重启电脑，然后再次运行此脚本
    echo.
    goto :install_docker
)

:install_docker
echo 正在下载 Docker Desktop 安装包...
powershell -Command "Invoke-WebRequest -Uri 'https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe' -OutFile '%TEMP%\DockerInstaller.exe'"
if %errorlevel% neq 0 (
    echo [X] 下载失败，请手动安装 Docker Desktop
    echo     https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)
echo 正在安装 Docker Desktop（可能需要几分钟）...
"%TEMP%\DockerInstaller.exe" install --quiet --accept-license
echo.
echo [OK] Docker Desktop 已安装
echo [!] 请重启电脑，然后再次双击运行此脚本完成部署
echo.
pause
exit /b 0

:check_docker_running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Docker 未运行，正在启动 Docker Desktop...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo     等待 Docker 启动中（约30秒）...
    timeout /t 30 /nobreak >nul
    docker info >nul 2>&1
    if %errorlevel% neq 0 (
        echo [!] Docker 还在启动，再等30秒...
        timeout /t 30 /nobreak >nul
    )
)
echo [OK] Docker 正在运行

:: 配置 AI 模型
echo.
echo [2/4] 配置 AI 模型
echo.
echo   请选择 AI 模型:
echo     1) Anthropic Claude (推荐)
echo     2) OpenAI (GPT)
echo     3) Google Gemini
echo     4) OpenRouter (聚合多模型)
echo.
set /p ai_choice="请输入数字 [1-4，默认1]: "
if "%ai_choice%"=="" set ai_choice=1

if "%ai_choice%"=="1" (
    set AI_KEY_NAME=ANTHROPIC_API_KEY
    set /p api_key="请输入 Anthropic API Key: "
)
if "%ai_choice%"=="2" (
    set AI_KEY_NAME=OPENAI_API_KEY
    set /p api_key="请输入 OpenAI API Key: "
)
if "%ai_choice%"=="3" (
    set AI_KEY_NAME=GEMINI_API_KEY
    set /p api_key="请输入 Gemini API Key: "
)
if "%ai_choice%"=="4" (
    set AI_KEY_NAME=OPENROUTER_API_KEY
    set /p api_key="请输入 OpenRouter API Key: "
)

if "%api_key%"=="" (
    echo [X] API Key 不能为空
    pause
    exit /b 1
)
echo [OK] AI 模型配置完成

:: 配置消息平台（可选）
echo.
echo [3/4] 配置消息平台（可选）
echo.
echo   1) Telegram
echo   2) WhatsApp (启动后扫码，无需Token)
echo   3) 跳过，稍后配置
echo.
set /p ch_choice="请选择 [默认3]: "
if "%ch_choice%"=="" set ch_choice=3

set CHANNEL_LINE=
if "%ch_choice%"=="1" (
    set /p tg_token="请输入 Telegram Bot Token: "
    set CHANNEL_LINE=TELEGRAM_BOT_TOKEN=!tg_token!
)

:: 下载并部署 OpenClaw
echo.
echo [4/4] 下载并部署 OpenClaw...

set INSTALL_DIR=%USERPROFILE%\openclaw
if exist "%INSTALL_DIR%" (
    echo 检测到已有安装目录，将使用现有目录
) else (
    echo 正在克隆 OpenClaw 仓库...
    git clone --depth 1 https://github.com/openclaw/openclaw.git "%INSTALL_DIR%" 2>nul
    if %errorlevel% neq 0 (
        echo [!] Git 未安装，使用备用方式下载...
        powershell -Command "Invoke-WebRequest -Uri 'https://github.com/openclaw/openclaw/archive/refs/heads/main.zip' -OutFile '%TEMP%\openclaw.zip'"
        powershell -Command "Expand-Archive -Path '%TEMP%\openclaw.zip' -DestinationPath '%TEMP%\openclaw-extract' -Force"
        move "%TEMP%\openclaw-extract\openclaw-main" "%INSTALL_DIR%"
    )
)

:: 生成 .env 配置
echo 正在生成配置文件...
(
    echo %AI_KEY_NAME%=%api_key%
    echo OPENCLAW_GATEWAY_BIND=localhost
    if not "%CHANNEL_LINE%"=="" echo %CHANNEL_LINE%
) > "%INSTALL_DIR%\.env"

:: 启动服务
echo 正在启动 OpenClaw（首次构建可能需要几分钟）...
cd /d "%INSTALL_DIR%"
docker compose up -d --build

echo.
echo  ============================================
echo     部署完成！
echo  ============================================
echo.
echo  安装目录: %INSTALL_DIR%
echo  配置文件: %INSTALL_DIR%\.env
echo.
echo  常用操作（在命令行中执行）:
echo    cd %INSTALL_DIR%
echo    docker compose logs -f     查看日志
echo    docker compose restart     重启
echo    docker compose down        停止
echo.
echo  如需修改配置，编辑 %INSTALL_DIR%\.env 后重启
echo.
pause
