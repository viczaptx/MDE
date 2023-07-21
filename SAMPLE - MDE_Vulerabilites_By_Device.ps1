# That code gets the App Context Token
# Paste below your Tenant ID, App ID and App Secret (App key).

$tenantId = ### Paste your tenant ID here
$appId = ### Paste your Application ID here
$appSecret = ### Paste your Application secret here

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
            version               = $machine.version
            agentVersion          = $machine.agentVersion
            osBuild               = $machine.osBuild
            isaadJoined           = $machine.isAadJoined
            lastIpAddress         = $machine.lastIpAddress
            lastExternalIpAddress = $machine.lastExternalIpAddress
            healthstatus          = $machine.healthStatus
            CVE                   = $vulnerability.cveID
            productName           = $vulnerability.productName
            productVendor         = $vulnerability.productVendor
            productVersion        = $vulnerability.Version
            fixingKBID            = $(if ($null -eq $vulnerability.fixingKBID) { $vulnerability.fixingKbId }; if ($null -ne $vulnerability.fixingKBID) { "KB$($vulnerability.FixingKBID)" })
        }
        $vuln = New-Object -typename PSobject -property $machineDataHash
        $endingData.Add($vuln) | Out-Null
    }
}

$endingData