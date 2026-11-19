@echo off
rem Runs the game's automated tests headless. Exit code 0 = all passed, and no unexpected engine ERROR lines.
rem Set GODOT to your Godot console exe if it's somewhere else.
if "%GODOT%"=="" set GODOT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
C:\ProgramData\anaconda3\python.exe "%~dp0run_tests.py" "%GODOT%" "%~dp0..\game"
