@echo off
rem Opens the project in the Godot editor (press F5 there to play).
if "%GODOT_GUI%"=="" set GODOT_GUI=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
start "" "%GODOT_GUI%" --editor --path "%~dp0..\game"
