@echo off
del /Q /S  %Temp%\*
del /Q /S c:\windows.old\*
del /Q /S c:\windows10upgrade\*
del /Q /S c:\windows\softwaredistrubution\download\*
ipconfig /flushdns
del /Q /S C:\Users\%USERNAME%\AppData\Local\Temp\*
del /Q /S C:\Users\%USERNAME%\AppData\Local\Temp\*
del /Q /S C:\Users\%USERNAME%\AppData\Local\NVIDIA\DXCache\*
del /Q /S  C:\Users\%USERNAME%\AppData\Local\NVIDIA\GLCache\*
del /Q /S C:\ProgramData\NVIDIA Corporation\NV_Cache\*

set /p "directory=Enter your COD cache folder location: "

if exist "%directory%" (
    echo Removing all files and folders from %directory%...
    rd /s /q "%directory%" 2>nul
    mkdir "%directory%"
    echo Cleanup complete.
) else (
    echo Directory does not exist.
)

pause
