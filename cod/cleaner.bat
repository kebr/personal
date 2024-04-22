@echo off

cls

rem Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script must be run as administrator.
    pause
    exit /b
)



echo Window Cleaner v1.0.0
echo  %date% %time%
echo.

set /p cleanup="Would you like to proceed with cleaning up temporary folders? (yes/no): "
if /i "%cleanup%"=="yes" (
    echo Cleaning temporary folders...
del /f /s /q %temp%\*.*
del /f /s /q c:\windows.old\*
del /f /s /q C:\Users\%USERNAME%\AppData\Local\NVIDIA\GLCache\*
del /f /s /q C:\Users\%USERNAME%\AppData\Local\NVIDIA\DXCache\*
del /f /s /q %systemroot%\Temp\*.*
del /f /s /q %systemroot%\Prefetch\*.*
del /f /s /q %systemdrive%\Windows\SoftwareDistribution\Download\*.*
echo.
    echo Temporary folders cleaned.
) else (
    echo.
    echo Skipping temporary folders cleanup.
)

echo.
set /p maintenance="Would you like to proceed with general maintenance tasks? (yes/no): "
if /i "%maintenance%"=="yes" (
    echo Running general maintenance tasks...
    echo Date and Time: %datetime% > cleanup.log
    rem Display current filesystem usage of all drives
    echo Current Filesystem Usage of all Drives: >> cleanup.log
    wmic logicaldisk get caption, freespace, size >> cleanup.log


    rem Cleaning network DNS cache
    ipconfig /flushdns

    set /p diskclean="Run disk cleanup? (yes/no): "
    if /i "%diskclean%"=="yes" (
        rem Run disk cleanup utility
        echo Running Disk Cleanup... >> cleanup.log
        cleanmgr /sagerun:1
    ) else (
        echo Skipping disk cleanup tasks.
    )


    set /p defrag="Run disk defragmentation? (yes/no): "
    if /i "%defrag%"=="yes" (
        rem Run disk defragmentation
        echo Running Disk Defragmentation... >> cleanup.log
        defrag /C /V 
    ) else (
        echo Skipping disk defragmentation tasks.
    )


    set /p sfc="Run system file checker? (yes/no): "
    if /i "%sfc%"=="yes" (
        rem Run system file checker
        echo Running System File Checker... >> cleanup.log
        sfc /scannow
    ) else (
        echo Skipping system file checker tasks.
    )

    echo Maintenance tasks completed.
) else (
    echo Skipping general maintenance tasks.
)


echo Done
