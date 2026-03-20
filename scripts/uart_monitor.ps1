# UART Monitor - Beeps when data arrives (useful for finding correct pins)
# USAGE: Run script, then move/wiggle wires on JP3 pins until you hear a beep
# CHANGE COM3 to your COM port number if different

$comPort = 'COM3'

$port = New-Object System.IO.Ports.SerialPort $comPort, 115200, 'None', 8, 'One'
$port.Open()

Write-Host "Monitoring $comPort for 60 seconds..."
Write-Host "Move wires around - you'll hear a BEEP when data arrives!"
Write-Host ""

$end = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $end) {
    $b = $port.BytesToRead
    if ($b -gt 0) {
        Write-Host "*** GOT $b BYTES! Current pin arrangement works! ***"
        [Console]::Beep(1000, 300)
        $port.DiscardInBuffer()
    }
    Start-Sleep -Milliseconds 200
}

$port.Close()
Write-Host "Done."
