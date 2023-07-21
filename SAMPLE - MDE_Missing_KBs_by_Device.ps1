Function Connect-Azure
{
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
}

Connect-Azure

$machinesUrl = "https://api.securitycenter.microsoft.com/api/machines"
$machinesResponse = Invoke-WebRequest -Method Get -Uri $machinesUrl -Headers $headers -ErrorAction Stop 
$machineIDs = ($machinesResponse.Content | ConvertFrom-Json).value

forEach ($ID in $machineIDs)
    {
    $today = Get-Date
    $lastSeenTime = Get-Date $ID.lastSeen
    if($lastSeenTime -gt $today.AddDays(-7))
        {
        $MachineID = $ID.id
        $missingKBsURL = "https://api.securitycenter.microsoft.com/api/machines/$MachineID/getmissingkbs"
        $missingKBsResponse = Invoke-WebRequest -Method Get -Uri $missingKBsUrl -Headers $headers -ErrorAction Stop
         if( (($missingKBsResponse.Content | ConvertFrom-Json).value).length -gt 0)
            {
            Write-Host $ID.computerDnsName -ForegroundColor Green
            Write-Host $ID.id -ForegroundColor Green
            ($missingKBsResponse.Content | ConvertFrom-Json).value | fl name, url
            }
        }
    }
