@echo off
rem 用本机已下载的 Godot 4.3 直接运行工程（也可用编辑器打开 project.godot）
set "GODOT=C:\Users\udokw\AppData\Local\Temp\godot43\Godot_v4.3-stable_win64.exe"
if not exist "%GODOT%" (
  echo 未找到 Godot 4.3，请修改本脚本中的 GODOT 路径，或用编辑器打开 project.godot 后按 F5。
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
