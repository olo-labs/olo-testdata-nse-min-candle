```bat
@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "REPO_URL=https://github.com/olo-labs/olo-testdata-nse-min-candle.git"
set "REPO_PATH=olo-labs/olo-testdata-nse-min-candle.git"
set "BRANCH=main"
set "CREDENTIAL_FILE=%TEMP%\github-temp-auth-%RANDOM%-%RANDOM%.txt"

echo ============================================
echo Checking repository...
echo ============================================

git rev-parse --show-toplevel >nul 2>&1
if errorlevel 1 (
    echo ERROR: Put this BAT file inside the Git repository.
    goto :failed
)

rem Move to the actual repository root.
for /f "delims=" %%R in ('git rev-parse --show-toplevel') do cd /d "%%R"

echo Repository:
cd

echo.
echo ============================================
echo Configuring HTTPS remote...
echo ============================================

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    git remote add origin "%REPO_URL%"
) else (
    git remote set-url origin "%REPO_URL%"
)

rem Remove any separate SSH push URL.
git config --local --unset-all remote.origin.pushurl >nul 2>&1

rem Use Git Credential Manager only for this repository.
git config --local --replace-all credential.helper ""
git config --local --add credential.helper manager
git config --local credential.useHttpPath true
git config --local credential.gitHubAuthModes browser
git config --local credential.interactive true

echo Stored remote:
git config --local --get remote.origin.url

echo.
echo ============================================
echo Removing cached login for this repository...
echo ============================================

> "%CREDENTIAL_FILE%" echo protocol=https
>>"%CREDENTIAL_FILE%" echo host=github.com
>>"%CREDENTIAL_FILE%" echo path=%REPO_PATH%
>>"%CREDENTIAL_FILE%" echo.

git credential reject < "%CREDENTIAL_FILE%"
del /q "%CREDENTIAL_FILE%" >nul 2>&1

echo.
echo ============================================
echo Temporary browser-authenticated push...
echo ============================================
echo Use the GitHub account that has access to:
echo olo-labs/olo-testdata-nse-min-candle
echo.

rem Ignore global/system configuration during this push.
rem This prevents a global HTTPS-to-SSH rewrite and avoids the system account.
set "GIT_CONFIG_NOSYSTEM=1"
set "GIT_CONFIG_GLOBAL=NUL"

git ^
  -c credential.helper= ^
  -c credential.helper=manager ^
  -c credential.useHttpPath=true ^
  -c credential.gitHubAuthModes=browser ^
  -c credential.interactive=true ^
  push --recurse-submodules=check --progress ^
  "%REPO_URL%" "refs/heads/%BRANCH%:refs/heads/%BRANCH%"

set "PUSH_RESULT=%ERRORLEVEL%"

rem Restore normal Git configuration before deleting temporary credentials.
set "GIT_CONFIG_NOSYSTEM="
set "GIT_CONFIG_GLOBAL="

echo.
echo ============================================
echo Removing temporary browser credential...
echo ============================================

> "%CREDENTIAL_FILE%" echo protocol=https
>>"%CREDENTIAL_FILE%" echo host=github.com
>>"%CREDENTIAL_FILE%" echo path=%REPO_PATH%
>>"%CREDENTIAL_FILE%" echo.

git credential reject < "%CREDENTIAL_FILE%"
del /q "%CREDENTIAL_FILE%" >nul 2>&1

if not "%PUSH_RESULT%"=="0" goto :failed

echo.
echo ============================================
echo Push completed successfully.
echo Temporary credential was removed.
echo ============================================
goto :end

:failed
echo.
echo ============================================
echo Push failed.
echo ============================================
echo.
echo Verify Git Credential Manager is available:
echo     git credential-manager version
echo.
echo Also ensure the browser authorizes the correct
echo GitHub user, not the olo-orgs account.

:end
echo.
pause
endlocal
```
