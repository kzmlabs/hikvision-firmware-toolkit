# UART Raw Test - Read raw data from NVR to verify connection
# USAGE: Connect wires to NVR, power on NVR, run this script
# CHANGE COM3 to your COM port number if different

$comPort = 'COM3'

$port = New-Object System.IO.Ports.SerialPort $comPort, 115200, 'None', 8, 'One'
$port.Encoding = [System.Text.Encoding]::GetEncoding(28591)
$port.Open()
$port.DiscardInBuffer()

Write-Host "Reading UART on $comPort for 15 seconds..."
Write-Host "If NVR is off, power it on now to see boot messages."
Write-Host ""

$end = (Get-Date).AddSeconds(15)
$allData = ""

while ((Get-Date) -lt $end) {
    $data = $port.ReadExisting()
    if ($data.Length -gt 0) {
        $allData += $data
        $clean = ($data -replace '[^\x20-\x7E\r\n]', '').Trim()
        if ($clean.Length -gt 0) { Write-Host $clean }
    }
    Start-Sleep -Milliseconds 100
}

$port.Close()

if ($allData.Length -eq 0) {
    Write-Host ""
    Write-Host "NO DATA received. Check:"
    Write-Host "  - Are wires connected to the correct JP3 pins?"
    Write-Host "  - Is the NVR powered on?"
    Write-Host "  - Is the USB adapter plugged in?"
} else {
    $bytes = [System.Text.Encoding]::GetEncoding(28591).GetBytes($allData.Substring(0, [Math]::Min(50, $allData.Length)))
    $unique = ($bytes | Sort-Object -Unique | ForEach-Object { '0x{0:X2}' -f $_ }) -join ', '
    Write-Host ""
    Write-Host "Total bytes: $($allData.Length)"
    Write-Host "Unique byte values: $unique"

    if ($unique -eq '0xFF') {
        Write-Host "ALL 0xFF = UART idle. NVR console is silent (already booted). Power cycle NVR."
    } elseif ($unique -eq '0x00') {
        Write-Host "ALL 0x00 = TX/RX wires are SWAPPED. Swap them and try again."
    }
}
