

@echo off
title Restore Wi-Fi Adapter DNS
echo ======================================================================
echo    WiFi Usage Monitor -- Restore Wi-Fi DNS Configuration
echo ======================================================================
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
set "BACKUP_FILE=%~dp0wifi_dns_backup.txt"

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $bf = '%BACKUP_FILE%'; $verified = $false; if (Test-Path $bf) { $saved = (Get-Content -Path $bf -Raw -ErrorAction SilentlyContinue).Trim(); Write-Host ('[*] Found saved DNS backup: ' + $saved); if ($saved -eq 'DHCP') { Write-Host '[*] Restoring Wi-Fi adapter DNS to automatic (DHCP)...'; & netsh interface ip set dns name='Wi-Fi' dhcp; if ($LASTEXITCODE -ne 0) { Write-Host ('[ERROR] netsh command failed to set Wi-Fi DNS to DHCP (exit code ' + $LASTEXITCODE + ').'); Write-Host ('[NOTICE] Preserving backup file for recovery: ' + $bf); exit 1 } Start-Sleep -Milliseconds 600; $raw = (netsh interface ip show dns name='Wi-Fi' | Out-String); if ($raw -match 'through DHCP' -and $raw -notmatch 'Statically Configured' -and $raw -notmatch '127\.0\.0\.1') { $verified = $true } else { Write-Host '[ERROR] Verification failed: Adapter is not reporting clean DHCP configuration.' } } elseif ($saved -match '^(\d{1,3}\.){3}\d{1,3}(,(\d{1,3}\.){3}\d{1,3})*$') { Write-Host ('[*] Restoring static DNS servers: ' + $saved + '...'); $servers = $saved -split ','; $psSuccess = $false; try { Set-DnsClientServerAddress -InterfaceAlias 'Wi-Fi' -ServerAddresses $servers -ErrorAction Stop; $psSuccess = $true } catch { Write-Host ('[!] Set-DnsClientServerAddress encountered an error: ' + $_.Exception.Message); Write-Host '[*] Falling back to netsh for static DNS configuration...' } if (-not $psSuccess) { & netsh interface ip set dns name='Wi-Fi' static $servers[0]; if ($LASTEXITCODE -ne 0) { Write-Host ('[ERROR] netsh failed to set primary static DNS (exit code ' + $LASTEXITCODE + ').'); Write-Host ('[NOTICE] Preserving backup file for recovery: ' + $bf); exit 1 } for ($i = 1; $i -lt $servers.Count; $i++) { & netsh interface ip add dns name='Wi-Fi' $servers[$i] index=($i+1); if ($LASTEXITCODE -ne 0) { Write-Host ('[ERROR] netsh failed to add secondary DNS server ' + $servers[$i] + ' (exit code ' + $LASTEXITCODE + ').'); Write-Host ('[NOTICE] Preserving backup file for recovery: ' + $bf); exit 1 } } } Start-Sleep -Milliseconds 600; $currentObj = Get-DnsClientServerAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -ErrorAction SilentlyContinue; $currentIps = if ($currentObj) { $currentObj.ServerAddresses -join ',' } else { '' }; $raw = (netsh interface ip show dns name='Wi-Fi' | Out-String); if ($raw -match 'Statically Configured' -and $raw -notmatch '127\.0\.0\.1' -and $currentIps -eq $saved) { $verified = $true } else { Write-Host ('[ERROR] Verification failed: Configured servers (' + $currentIps + ') do not match backup (' + $saved + ').') } } else { Write-Host ('[ERROR] Saved configuration file contains invalid data: ' + $saved); Write-Host ('[NOTICE] Preserving backup file for manual inspection: ' + $bf); exit 1 } if ($verified) { Remove-Item -Path $bf -Force -ErrorAction SilentlyContinue; Write-Host '[SUCCESS] Original Wi-Fi DNS configuration has been restored and verified.'; exit 0 } else { Write-Host '[ERROR] Verification failed! DNS settings could not be verified.'; Write-Host ('[NOTICE] Preserving backup file for recovery: ' + $bf); exit 1 } } else { Write-Host ('[!] No saved configuration file found (' + $bf + ').'); $raw = (netsh interface ip show dns name='Wi-Fi' | Out-String); $serversObj = Get-DnsClientServerAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -ErrorAction SilentlyContinue; $servers = if ($serversObj) { $serversObj.ServerAddresses } else { @() }; if ($raw -match '127\.0\.0\.1' -or ($servers -contains '127.0.0.1')) { Write-Host ''; Write-Host '======================================================================'; Write-Host ' [ERROR] Wi-Fi adapter is currently configured with 127.0.0.1 and'; Write-Host '         no backup file was found!'; Write-Host ''; Write-Host ' [ABORT] Cannot safely determine whether the original configuration was'; Write-Host '         automatic (DHCP) or static DNS servers.'; Write-Host '         The system will NOT assume DHCP.'; Write-Host ''; Write-Host ' [ACTION REQUIRED] Please configure your Wi-Fi DNS manually in Windows:'; Write-Host '   Settings > Network & internet > Wi-Fi > Hardware properties > DNS'; Write-Host '======================================================================'; exit 1 } elseif ($raw -match 'through DHCP' -and $raw -notmatch 'Statically Configured') { Write-Host '[SUCCESS] Wi-Fi adapter is already configured with automatic DNS (DHCP).'; exit 0 } else { Write-Host ('[SUCCESS] Wi-Fi adapter is not set to 127.0.0.1. Current servers: ' + ($servers -join ', ')); exit 0 } } }"

if %ERRORLEVEL% EQU 0 (
    ipconfig /flushdns >nul 2>&1
    echo.
    echo ======================================================================
    echo  DNS cache flushed. Network settings restored.
    echo ======================================================================
    echo.
) else (
    echo.
    echo ======================================================================
    echo  [FAILURE] Could not verify Wi-Fi DNS restoration.
    echo  Please check your network settings manually.
    echo  The backup file has been preserved for recovery:
    echo  %BACKUP_FILE%
    echo ======================================================================
    echo.
)
pause
