
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

$PatchID = "5025229"

$machinesUrl = "https://api.securitycenter.microsoft.com/api/machines?"
$machinesResponse = Invoke-WebRequest -Method Get -Uri $machinesUrl -Headers $headers -ErrorAction Stop 
$machines = ($machinesResponse.Content | ConvertFrom-Json).value

forEach ($machine in $machines)
    {
    $today = Get-Date
    $lastSeenTime = Get-Date $machine.lastSeen
    if($lastSeenTime -gt $today.AddDays(-7))
        {
        $machineID = $machine.id
        $missingKBsURL = "https://api.securitycenter.microsoft.com/api/machines/$machineID/getmissingkbs"
        $missingKBsResponse = Invoke-WebRequest -Method Get -Uri $missingKBsUrl -Headers $headers -ErrorAction Stop
         if( (($missingKBsResponse.Content | ConvertFrom-Json).value).length -gt 0)
            {
            if((($missingKBsResponse.Content | ConvertFrom-Json).value).id -ccontains $PatchID)
                {
                Write-Host $machine.computerDnsName -ForegroundColor Green
                # Write-Host $machineID -ForegroundColor Green
                # ($missingKBsResponse.Content | ConvertFrom-Json).value | ?{$_.id -eq $PatchID} | fl name, url
                }

            }
        }
    }

