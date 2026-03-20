# Loopback Test - Verify USB-UART adapter TX/RX works
# USAGE: Touch TX and RX wires together, then run this script
# CHANGE COM3 to your COM port number if different

$comPort = 'COM3'

$port = New-Object System.IO.Ports.SerialPort $comPort, 115200, 'None', 8, 'One'
$port.Encoding = [System.Text.Encoding]::GetEncoding(28591)
$port.ReadTimeout = 2000
$port.Open()
$port.DiscardInBuffer()

Write-Host "LOOPBACK TEST on $comPort"
Write-Host "Make sure TX and RX wires are touching each other!"
Write-Host "Sending 'HELLO123'..."

$port.Write("HELLO123")
Start-Sleep -Milliseconds 500
$resp = $port.ReadExisting()
$clean = ($resp -replace '[^\x20-\x7E]', '')

if ($clean -match "HELLO123") {
    Write-Host "SUCCESS! Adapter TX and RX are working. Got back: $clean"
} elseif ($clean.Length -gt 0) {
    Write-Host "Got something but garbled: $clean"
    Write-Host "Check baud rate or adapter."
} else {
    Write-Host "NOTHING received. Adapter TX might not be working!"
    Write-Host "Check: USB plugged in? Correct COM port? Wires touching?"
}

$port.Close()
