@ECHO OFF

:: Log the startup date and time.
SET timehour=%time:~0,2%
SET timestamp=%date:~-4,4%%date:~-10,2%%date:~-7,2%-%timehour: =0%%time:~3,2%
SET startuptasklogsubdir=FixAuth
SET startuptasklogdir=%PathToStartupLogs%\%startuptasklogsubdir%\
SET startuptasklog=%startuptasklogdir%\startup-%timestamp%.txt

IF NOT EXIST %startuptasklogdir% MKDIR %startuptasklogdir%

IF "%ComputeEmulatorRunning%" == "true" (
    ECHO Detected running in an emulator. Skipping the modification of IIS authentication modes. 2>&1
) ELSE (
    ECHO Starting up %0. >> "%startuptasklog%" 2>&1

    :: For some reason, the authentication changes applied to Web.Config are not working,
    :: so these changes need to be applied via appcmd instead.
    %systemroot%\system32\inetsrv\appcmd.exe set config -section:anonymousAuthentication -enabled:%ENABLE_ANONYMOUS_AUTHENTICATION%
    %systemroot%\system32\inetsrv\appcmd.exe set config -section:windowsAuthentication -enabled:%ENABLE_WINDOWS_AUTHENTICATION%
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