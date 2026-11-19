@echo off
rem Starts the game (the endless arena). Set GODOT to your Godot exe if it's somewhere else.
if "%GODOT_GUI%"=="" set GODOT_GUI=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
start "" "%GODOT_GUI%" --path "%~dp0..\game"
