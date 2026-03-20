# Setup Firewall - Allow TFTP traffic through Windows Firewall

Write-Host "Adding Windows Firewall rules for TFTP..."

New-NetFirewallRule -DisplayName 'TFTP Server Inbound' -Direction Inbound -Protocol UDP -LocalPort 69 -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName 'TFTP All UDP Inbound' -Direction Inbound -Protocol UDP -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName 'TFTP All UDP Outbound' -Direction Outbound -Protocol UDP -Action Allow -ErrorAction SilentlyContinue | Out-Null

Write-Host "Firewall rules added successfully."
Write-Host ""
Write-Host "To remove these rules later:"
Write-Host "  Remove-NetFirewallRule -DisplayName 'TFTP Server Inbound'"
Write-Host "  Remove-NetFirewallRule -DisplayName 'TFTP All UDP Inbound'"
Write-Host "  Remove-NetFirewallRule -DisplayName 'TFTP All UDP Outbound'"
