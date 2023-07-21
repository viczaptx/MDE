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
$vulnerabilityUrl = "https://api.securitycenter.windows.com/api/vulnerabilities?"
$vulnerabilityResponse = Invoke-WebRequest -Method Get -Uri $vulnerabilityUrl -Headers $headers -ErrorAction Stop
$vulnerabilityData = $vulnerabilityResponse.Content | ConvertFrom-Json 

$Vulns = $vulnerabilityData.value
foreach ($vuln in $vulns)
    {
    if ($vuln.publishedon -match "^2023-04.*")
        {
        Write-Output $vuln | fl name, description, severity, cvssv3, publishedon
        }
    }

    foreach ($vuln in $vulns)
    {
    if ($vuln.publishedon -match "^2023-04.*" -and $vuln.severity -match "Critical|High")
        {
        Write-Output $vuln | fl name, description, severity, cvssv3, publishedon, updatedon
        }
    }
