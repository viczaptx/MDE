$Server = "172.16.22.141"
$Database = "testdb1"
$User = 'corp\administrator'
$Password = "TaniumPassword1!"
$file = "c:\temp\EPVulns.csv"

# That code gets the App Context Token
# Paste below your Tenant ID, App ID and App Secret (App key).

$tenantId = '516e405c-77db-4a4e-9491-483abfdba529' ### Paste your tenant ID here
$appId = '3c19e3f6-5784-4df4-b7f1-c3b90dcfdc83' ### Paste your Application ID here
$appSecret = 'IoA8Q~ag4mVTqFU8hrJdPO79nQzNzhUqa.yoFc-Z' ### Paste your Application secret here

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

# Get vulnerabilties for each endpoint
$vulnerabilityUrl = "https://api.securitycenter.windows.com/api/vulnerabilities/machinesVulnerabilities?"
$vulnerabilityResponse = Invoke-WebRequest -Method Get -Uri $vulnerabilityUrl -Headers $headers -ErrorAction Stop
$vulnerabilityData = $vulnerabilityResponse.Content | ConvertFrom-Json 
    
   
$machineURL = "https://api.securitycenter.windows.com/api/machines"
$machineResponse = Invoke-WebRequest -Method Get -Uri $machineURL -Headers $headers -ErrorAction Stop
$machineData = $machineResponse.Content | ConvertFrom-Json 
    
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

# Write results to CSV file (remove header row)
$endingData | Export-Csv $file -NoTypeInformation
(Get-Content $file | Select-Object -Skip 1) | Set-Content $file


# Import CSV data to SQL
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=$Server;Database=$Database;User ID=$User;Password=$Password;Integrated Security = True;"
$SqlConnection.Open()

$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.Connection = $SqlConnection

$Command = @"
    BULK INSERT Testdb1.dbo.EPFindings
    FROM '$file'
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

