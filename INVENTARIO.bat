@echo off
chcp 65001 >nul
title Inventario de PC
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0inventario.ps1"
echo.
pause
