try {
    # Function to collect TPM Information with error handling and fallback method
    function Collect-TpmInfo {
        try {
            # Attempt to get TPM data using Get-CimInstance
            $tpm = Get-CimInstance -ClassName Win32_Tpm -ErrorAction Stop
            if ($tpm) {
                return @{
                    "TPM Manufacturer ID" = $tpm.ManufacturerID
                    "TPM Manufacturer Version" = $tpm.ManufacturerVersion
                    "TPM Serial Number" = $tpm.SerialNumber
                }
            } else {
                Write-Host "TPM is not available or supported on this system." -ForegroundColor Yellow
                return @{
                    "TPM Manufacturer ID" = "Not Available"
                    "TPM Manufacturer Version" = "Not Available"
                    "TPM Serial Number" = "Not Available"
                }
            }
        } catch {
            # If Get-CimInstance fails, fallback to Get-WmiObject
            try {
                $tpm = Get-WmiObject -Class Win32_Tpm -ErrorAction Stop
                if ($tpm) {
                    return @{
                        "TPM Manufacturer ID" = $tpm.ManufacturerID
                        "TPM Manufacturer Version" = $tpm.ManufacturerVersion
                        "TPM Serial Number" = $tpm.SerialNumber
                    }
                } else {
                    Write-Host "TPM is not available or supported on this system." -ForegroundColor Yellow
                    return @{
                        "TPM Manufacturer ID" = "Not Available"
                        "TPM Manufacturer Version" = "Not Available"
                        "TPM Serial Number" = "Not Available"
                    }
                }
            } catch {
                # If both Get-CimInstance and Get-WmiObject fail, return 'Not Available'
                return @{
                    "TPM Manufacturer ID" = "Not Available"
                    "TPM Manufacturer Version" = "Not Available"
                    "TPM Serial Number" = "Not Available"
                }
            }
        }
    }

    # Function to collect Secure Boot Information
    function Collect-SecureBootInfo {
        try {
            # Use Confirm-SecureBootUEFI cmdlet to check if Secure Boot is enabled or disabled
            $secureBootStatus = Confirm-SecureBootUEFI
            return @{
                "Secure Boot" = if ($secureBootStatus) { "Enabled" } else { "Disabled" }
            }
        } catch {
            Write-Host "Unable to determine Secure Boot status." -ForegroundColor Yellow
            return @{
                "Secure Boot" = "Not Available"
            }
        }
    }

    # Function to get selected hardware and network information
    function Get-FilteredHardwareInfo {
        param (
            [switch]$ExportToCSV,
            [string]$OutputFile = "FilteredHardwareInfo.csv",
            [switch]$LogErrors
        )

        # Create an empty hashtable to store hardware details
        $hardwareDetails = @{}

        # Function to handle errors and log them
        function Log-Error {
            param ($message)
            if ($LogErrors) {
                $message | Out-File -Append -FilePath "HardwareInfo_Log.txt"
            }
            Write-Host "Error: $message" -ForegroundColor Red
        }

        Write-Host
        Write-Host "=======================================" -ForegroundColor Cyan
        Write-Host "  DigitalZolic's Hardware IDs Retriever"
        Write-Host "                                      "
        Write-Host "    Discord & Github: @DigitalZolic"
        Write-Host "                                      "
        Write-Host "   Version: 1.0 - Updated: 2025-06-18"
        Write-Host "                                      "
        Write-Host "=======================================" -ForegroundColor Cyan
        Write-Host
        Write-Host "    Scanning Hardware... Please wait."
        Write-Host
        Start-Sleep -Seconds 3  

        # Helper function to collect information
        function Collect-Info {
            param (
                [string]$ComponentName,
                [scriptblock]$GetInfoScript
            )
            try {
                $result = & $GetInfoScript
                if ($result) {
                    $hardwareDetails[$ComponentName] = $result
                } else {
                    $hardwareDetails[$ComponentName] = "Not Available"
                }
            } catch {
                Log-Error "Failed to retrieve ${ComponentName}: $_"
                $hardwareDetails[$ComponentName] = "Error Retrieving ${ComponentName}"
            }
        }

        # Collect Network Information (Optimized)
        $networkAdapter = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        Collect-Info "Local IPv4 Address" { $networkAdapter.IPAddress | Where-Object { $_ -match '\d+\.\d+\.\d+\.\d+' } | Select-Object -First 1 }
        Collect-Info "Public IPv4 Address" {
            try { (Invoke-RestMethod -Uri "http://ipinfo.io/json" -TimeoutSec 5).ip } catch { "Unable to retrieve" }
        }
        Collect-Info "Public DNS Address" {
            try { (Resolve-DnsName -Name myip.opendns.com -Server resolver1.opendns.com).IPAddress } catch { "Unable to retrieve" }
        }
        Collect-Info "Public MAC Address" { $networkAdapter.MACAddress | Select-Object -First 1 }

        # Collect BIOS Information
        Collect-Info "BIOS Vendor Name" { (Get-CimInstance -ClassName Win32_BIOS).Manufacturer }
        Collect-Info "BIOS Version" { (Get-CimInstance -ClassName Win32_BIOS).SMBIOSBIOSVersion }
        Collect-Info "BIOS Release Date" { (Get-CimInstance -ClassName Win32_BIOS).ReleaseDate }
        Collect-Info "BIOS Serial Number" { (Get-CimInstance -ClassName Win32_BIOS).SerialNumber }

        # Collect System Information (modified for Serial Number fallback)
        $systemInfo = Get-CimInstance -ClassName Win32_ComputerSystem
        $systemSerial = $systemInfo.SerialNumber
        if (-not $systemSerial) {
            # If the serial number is not found in Win32_ComputerSystem, query Win32_BIOS
            $biosInfo = Get-CimInstance -ClassName Win32_BIOS
            $systemSerial = $biosInfo.SerialNumber
        }
        Collect-Info "System Manufacture" { $systemInfo.Manufacturer }
        Collect-Info "System Product" { $systemInfo.Model }
        Collect-Info "System Version" { $systemInfo.Version }
        Collect-Info "System SKU Number" { $systemInfo.SystemSKUNumber }
        Collect-Info "System Family Number" { $systemInfo.SystemFamily }
        Collect-Info "System Serial Number" { $systemSerial }
        Collect-Info "System UUID" { (Get-CimInstance -ClassName Win32_ComputerSystemProduct).UUID }

        # Collect Motherboard Information
        Collect-Info "Motherboard Manufacture" { (Get-CimInstance -ClassName Win32_BaseBoard).Manufacturer }
        Collect-Info "Motherboard Product" { (Get-CimInstance -ClassName Win32_BaseBoard).Product }
        Collect-Info "Motherboard Version" { (Get-CimInstance -ClassName Win32_BaseBoard).Version }
        Collect-Info "Motherboard Asset Tag" { (Get-CimInstance -ClassName Win32_BaseBoard).AssetTag }
        Collect-Info "Motherboard Serial Number" { (Get-CimInstance -ClassName Win32_BaseBoard).SerialNumber }

        # Collect Processor Information (including new data)
        Collect-Info "Processor Serial Number" { (Get-CimInstance -ClassName Win32_Processor).ProcessorId }
        Collect-Info "Processor Asset Tag" { (Get-CimInstance -ClassName Win32_Processor).AssetTag }
        Collect-Info "Processor Parts Number" { (Get-CimInstance -ClassName Win32_Processor).PartNumber }

        # Collect Chassis Information (new data)
        Collect-Info "Chassis Manufacture" { (Get-CimInstance -ClassName Win32_SystemEnclosure).Manufacturer }
        Collect-Info "Chassis Tag Serial Number" { (Get-CimInstance -ClassName Win32_SystemEnclosure).Tag }
        Collect-Info "Chassis Serial Number" { (Get-CimInstance -ClassName Win32_SystemEnclosure).SerialNumber }

        # Collect RAM and Storage Information
        Collect-Info "RAM Serial Number" { (Get-CimInstance -ClassName Win32_PhysicalMemory).SerialNumber }
        Collect-Info "HDD/SSD Serial Number" { (Get-CimInstance -ClassName Win32_DiskDrive).SerialNumber }

        # Collect TPM Information with improved error handling and fallback method
        $tpmInfo = Collect-TpmInfo
        $hardwareDetails += $tpmInfo

        # Collect Secure Boot Information
        $secureBootInfo = Collect-SecureBootInfo
        $hardwareDetails += $secureBootInfo

        # Function to generate a unique hardware fingerprint using MD5
        function Get-HardwareFingerprint {
            param (
                [string]$uuid,
                [string]$biosSerial,
                [string]$diskSerial,
                [string]$processorSerial,
                [string]$motherboardSerial,
                [string]$ramSerial
            )
            # Concatenate the hardware details into a single string, now including RAM Serial Number
            $fingerprintString = "$uuid-$biosSerial-$diskSerial-$processorSerial-$motherboardSerial-$ramSerial"
            
            # Generate an MD5 hash of the concatenated string
            return [BitConverter]::ToString([System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($fingerprintString))) -replace '-'
        }

        # Generate Hardware Fingerprint
        $hardwareDetails["Hardware Fingerprint"] = Get-HardwareFingerprint $hardwareDetails['System UUID'] $hardwareDetails['BIOS Serial Number'] $hardwareDetails['HDD/SSD Serial Number'] $hardwareDetails['Processor Serial Number'] $hardwareDetails['Motherboard Serial Number'] $hardwareDetails['RAM Serial Number']

        # Format the collected details for text output
        $hardwareDetailsFormatted = @"
=======================================
      Found Hardware Information
=======================================

Local IPv4 Address: $($hardwareDetails['Local IPv4 Address'])
Public IPv4 Address: $($hardwareDetails['Public IPv4 Address'])
Public DNS Address: $($hardwareDetails['Public DNS Address'])
Public MAC Address: $($hardwareDetails['Public MAC Address'])

=============== BIOS ===============
BIOS Vendor Name: $($hardwareDetails['BIOS Vendor Name'])
BIOS Version: $($hardwareDetails['BIOS Version'])
BIOS Release Date: $($hardwareDetails['BIOS Release Date'])
BIOS Serial Number: $($hardwareDetails['BIOS Serial Number'])

=============== SYSTEM ===============
System Manufacture: $($hardwareDetails['System Manufacture'])
System Product: $($hardwareDetails['System Product'])
System Version: $($hardwareDetails['System Version'])
System SKU Number: $($hardwareDetails['System SKU Number'])
System Family Number: $($hardwareDetails['System Family Number'])
System Serial Number: $($hardwareDetails['System Serial Number'])
System UUID: $($hardwareDetails['System UUID'])

=============== MOTHERBOARD ===============
Motherboard Manufacture: $($hardwareDetails['Motherboard Manufacture'])
Motherboard Product: $($hardwareDetails['Motherboard Product'])
Motherboard Version: $($hardwareDetails['Motherboard Version'])
Motherboard Asset Tag: $($hardwareDetails['Motherboard Asset Tag'])
Motherboard Serial Number: $($hardwareDetails['Motherboard Serial Number'])

=============== PROCESSOR ===============
Processor Serial Number: $($hardwareDetails['Processor Serial Number'])
Processor Asset Tag: $($hardwareDetails['Processor Asset Tag'])
Processor Parts Number: $($hardwareDetails['Processor Parts Number'])

=============== CHASSIS ===============
Chassis Manufacture: $($hardwareDetails['Chassis Manufacture'])
Chassis Tag Serial Number: $($hardwareDetails['Chassis Tag Serial Number'])
Chassis Serial Number: $($hardwareDetails['Chassis Serial Number'])

=============== RAM ===============
RAM Serial Number: $($hardwareDetails['RAM Serial Number'])

=============== HDD/SSD ===============
HDD/SSD Serial Number: $($hardwareDetails['HDD/SSD Serial Number'])

=============== FINGERPRINT ===============
Hardware Fingerprint: $($hardwareDetails['Hardware Fingerprint'])

=============== TPM ===============
TPM Manufacturer ID: $($hardwareDetails['TPM Manufacturer ID'])
TPM Manufacturer Version: $($hardwareDetails['TPM Manufacturer Version'])
TPM Serial Number: $($hardwareDetails['TPM Serial Number'])

=============== Secure Boot ===============
Secure Boot: $($hardwareDetails['Secure Boot'])

============================================================
"@

        # Display the formatted information in the console
        Write-Host $hardwareDetailsFormatted

        # Save the details to a file
        $currentDate = Get-Date -Format "MM-dd_HH-mm"
        $outputTextFile = "$env:USERPROFILE\Desktop\DigitalZolic_$currentDate.txt"
        $hardwareDetailsFormatted | Out-File -FilePath $outputTextFile -Encoding UTF8

        Write-Host "Information saved to: $outputTextFile" -ForegroundColor Cyan
        Write-Host
        Write-Host "Press Enter to exit..."
        Read-Host
    }

    # Run the function
    Get-FilteredHardwareInfo -LogErrors

} catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    Write-Host "The script encountered an issue. Please check the log file for more details."
    Read-Host "Press Enter to exit..."
}