@ECHO OFF

:: Log the startup date and time.
SET timehour=%time:~0,2%
SET timestamp=%date:~-4,4%%date:~-10,2%%date:~-7,2%-%timehour: =0%%time:~3,2%
SET startuptasklogsubdir=RemoteDesktop
SET startuptasklogdir=%PathToStartupLogs%\%startuptasklogsubdir%\
SET startuptasklog=%startuptasklogdir%\startup-%timestamp%.txt

IF NOT EXIST %startuptasklogdir% MKDIR %startuptasklogdir%

IF "%ComputeEmulatorRunning%" == "true" (
    ECHO Detected running in an emulator. Skipping enabling remote desktop. 2>&1
) ELSE (
    ECHO Starting up %0. >> "%startuptasklog%" 2>&1

    :: Call the file, redirecting all output to the StartupLog.txt log file.
    powershell -executionpolicy unrestricted ". %0\..\Ensure-RemoteDesktopEnabled.ps1; Ensure-RemoteDesktopEnabled -Verbose"  >> "%startuptasklog%" 2>&1
)

:: Log the completion of file/
ECHO Returned to %0. >> "%startuptasklog%" 2>&1

IF %ERRORLEVEL% EQU 0 (
   :: No errors occurred. Exit normally.
   ECHO Done >> "%startuptasklog%"
   EXIT /B 0
) ELSE (
   :: Log the error.
   ECHO An error occurred. The ERRORLEVEL = %ERRORLEVEL%.  >> "%startuptasklog%" 2>&1
   ECHO Done >> "%startuptasklog%"
   EXIT /B %ERRORLEVEL%
)