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

# IMPORT ENDPOINT NAMES FROM CSV FILE
$targetDevices = Import-Csv -Path C:\MDE_EP\endpoints.csv

# REMOVE ISOLATION ON TARGET DEVICES
forEach ($targetDevice in $targetDevices)
    {
    $machineUrl = "https://api.securitycenter.microsoft.com/api/machines/$targetDevice"
    $machineResponse = Invoke-WebRequest -Method Get -Uri $machineUrl -Headers $headers -ErrorAction Stop 
    $machine = ($machineResponse.Content | ConvertFrom-Json)
    $machineID = ($machine).id 
    Write-Host "$targetDevice"-ForegroundColor Yellow
    Write-Host "$machineid" -ForegroundColor Yellow

    $unisolateURL = "https://api.securitycenter.microsoft.com/api/machines/$machineID/unisolate"

    $unisolateBody = @{
        Comment = 'UnIsolate machine'
        }

    $unisolateResponse = Invoke-WebRequest -Method Post -Uri $unisolateURL -Body ($unisolateBody|ConvertTo-Json) -Headers $headers -ErrorAction Stop
    
    # REMOVE 'ISOLATED' TAG
    if ($unisolateResponse.StatusCode -eq "201")
        {
        $tagBody = @{
                    Value = 'Isolated'
                    Action = 'Remove'
                    }
        $tagUrl = "https://api.securitycenter.windows.com/api/machines/$machineID/tags" 
        $tagResponse = Invoke-WebRequest -Method Post -Uri $tagUrl -Body ($tagBody|ConvertTo-Json) -Headers $headers -ErrorAction Stop
        Write-Host "Created Successfully" -ForegroundColor Green
        
        }
    else
        {Write-Host "Failed" -ForegroundColor Red}
    }