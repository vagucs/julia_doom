@echo off
setlocal
set "PATH=C:\msys64\ucrt64\bin;%PATH%"
cd /d "%~dp0"
set "JULIA=%USERPROFILE%\.julia\juliaup\julia-1.13.1+0.x64.w64.mingw32\bin\julia.exe"
if not exist "%JULIA%" set "JULIA=julia"
"%JULIA%" --project=. run.jl %*
exit /b %ERRORLEVEL%
