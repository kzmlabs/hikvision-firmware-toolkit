# Fix IP - Set Ethernet adapter to 192.0.0.128 only
# Run this before starting TFTP server to prevent interface switching

# Remove all existing IPs
Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.IPAddress -ne '192.0.0.128') {
        Write-Host "Removing $($_.IPAddress)"
        Remove-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress $_.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
    }
}

# Disable DHCP to prevent auto-assignment
Set-NetIPInterface -InterfaceAlias 'Ethernet' -Dhcp Disabled -ErrorAction SilentlyContinue

# Ensure 192.0.0.128 exists
$existing = Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -ErrorAction SilentlyContinue
if (-not ($existing | Where-Object { $_.IPAddress -eq '192.0.0.128' })) {
    New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 192.0.0.128 -PrefixLength 24 -ErrorAction SilentlyContinue | Out-Null
}

Write-Host ""
Write-Host "Current Ethernet IPs:"
Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 | Select-Object IPAddress
