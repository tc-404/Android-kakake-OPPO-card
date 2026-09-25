@echo off
chcp 65001 >nul
title kakake . build
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_build.ps1"
echo.
pause
