############################################################################
#                                                                          #
# This Script will pull vulnerabilities by device from MDE and send to SQL #
#                                                                          #
############################################################################

# NOTE: THIS IS A SAMPLE SCRIPT AND SHOULD BE TREATED AS SUCH
# YOU MUST TEST AND ASSUME ALL RESPONSIBILITY
# Author: Victor Zapata
# Date / Version
# 07-26-2023 / 1.0


# SQL SERVER INFO
$Server = "<SQL SERVER NAME or IP>"
$Db = "<DATABASE NAME - SHORTNAME>"      ### Enter SQL database name - EXAMPLE: "VulnsDb"
$Table = "<FULL TABLE PATH>"             ### Enter SQL table name - EXAMPLE: "VulnsDb.dbo.Findings"
$tempFile = "<PATH TO CSV OUTPUT FILE>"  ### Enter full path to output file that will be created - EXAMPLE: "c:\Temp\DeviceVulns.csv"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# That code gets the App Context Token
# Paste below your Tenant ID, App ID and App Secret (App key).

$tenantId = '000000000000000000000' ### Paste your own tenant ID here
$appId = '000000000000000000000' ### Paste your own app ID here
$appSecret = '000000000000000000000' ### Paste your own app keys here

$resourceAppIdUri = 'https://api.securitycenter.microsoft.com'
$oAuthUri = "https://login.microsoftonline.com/$TenantId/oauth2/token"
$authBody = [Ordered] @{
     resource = "$resourceAppIdUri"
     client_id = "$appId"
     client_secret = "$appSecret"
     grant_type = 'client_credentials'
}

$authResponse = Invoke-RestMethod -Method Post -Uri $oAuthUri -Body $authBody -ErrorAction Stop
$token = $authResponse.access_token
    
#NOTE: Build our headers to ensure we can access the information.
$headers = @{ 
    'Content-Type' = 'application/json'
    Accept         = 'application/json'
    Authorization  = "Bearer $token" 
}

# GET VULNERABILITY DATA PER ENDPOINT
$vulnerabilityUrl = "https://api.securitycenter.windows.com/api/vulnerabilities/machinesVulnerabilities?"
$vulnerabilityData = (Invoke-WebRequest -Method Get -Uri $vulnerabilityUrl -Headers $headers -ErrorAction Stop).Content | ConvertFrom-Json

$machineURL = "https://api.securitycenter.windows.com/api/machines"
$machineData = (Invoke-WebRequest -Method Get -Uri $machineURL -Headers $headers -ErrorAction Stop).Content | ConvertFrom-Json
    
$endingData = New-Object -TypeName System.Collections.Generic.List[PsObject]
foreach ($machine in $machineData.value) {
    $MachineVulnerabilitylist = $vulnerabilityData.value | Where-object { $_.MachineID -eq $machine.ID }
    foreach ($vulnerability in $MachineVulnerabilitylist) {
        $machineDataHash = [ordered]@{
            MachineName           = $machine.computerDnsName
            MachineID             = $machine.id
            lastSeen              = $machine.lastSeen
            OSPlatform            = $machine.osPlatform
            lastIpAddress         = $machine.lastIpAddress
            CVE                   = $vulnerability.cveID
            productName           = $vulnerability.productName
            productVendor         = $vulnerability.productVendor
            fixingKBID            = $(if ($null -eq $vulnerability.fixingKBID) { $vulnerability.fixingKbId }; if ($null -ne $vulnerability.fixingKBID) { "KB$($vulnerability.FixingKBID)" })
        }
        $vuln = New-Object -typename PSobject -property $machineDataHash
        $endingData.Add($vuln) | Out-Null
    }
}

# WRITE RESULTS TO CSV FILE (remove header row)
$endingData | Export-Csv $tempFile -NoTypeInformation
(Get-Content $tempFile | Select-Object -Skip 1) | Set-Content $tempFile

# IMPORT CSV TO SQL
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=$Server;Database=$Db;Integrated Security=True;"
$SqlConnection.Open()

$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.Connection = $SqlConnection

$Command = @"
    BULK INSERT $Table
    FROM '$tempFile'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',  --CSV field delimiter
    ROWTERMINATOR = '\n',   --Use to shift the control to next row
    TABLOCK
    )
"@

$SqlCmd.CommandText = $Command
$SqlCmd.ExecuteNonQuery()
$SqlConnection.Close()

# CLEANUP TEMP FILE
Remove-Item -Path $tempFile -Force