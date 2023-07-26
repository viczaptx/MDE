# That code gets the App Context Token
# Paste below your Tenant ID, App ID and App Secret (App key).

$tenantId =  ### Paste your tenant ID here
$appId =     ### Paste your Application ID here
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

Function Deploy-IsolateByTag {

    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$targetTag,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$isolateType,
        [Parameter(Mandatory=$true, Position=2)]
        [string]$isolateComment
        )

	$machineUrl = "https://api.securitycenter.microsoft.com/api/machines?"
	$machines = ((Invoke-WebRequest -Method Get -Uri $machineUrl -Headers $headers -ErrorAction Stop).Content | ConvertFrom-Json).value
	$targetMachines = $machines | ?{$_.machineTags -match "$targetTag$"}

    if($targetMachines -eq $null)
        {Write-Host "No Devices Found with $targetTag Tag" -ForegroundColor Red}
    else
        {
        $devCount = ($targetMachines.id).count
        Write-Host "$devCount Device/s Found with $targetTag Tag" -ForegroundColor Cyan

		# LOOP THROUGH EACH TARGET DEVICE
		forEach ($target in $targetMachines)
			{
			$machineUrl = "https://api.securitycenter.microsoft.com/api/machines/$($target.Id)"
			$machineResponse = Invoke-WebRequest -Method Get -Uri $machineUrl -Headers $headers -ErrorAction Stop 
			Write-Host "$($target.computerDnsName)" -ForegroundColor Yellow
			Write-Host "$($target.Id)" -ForegroundColor Yellow

			# ISOLATE TARGET DEVICE
			$isolateURL = "https://api.securitycenter.microsoft.com/api/machines/$($target.Id)/isolate"

			$isolateBody = @{
				Comment = $isolateComment;
				IsolationType = $isolateType;
				}

			$isolateResponse = Invoke-WebRequest -Method Post -Uri $isolateURL -Body ($isolateBody|ConvertTo-Json) -Headers $headers -ErrorAction Stop
			
			# ADD 'ISOLATED' TAG
			if ($isolateResponse.StatusCode -eq "201")
				{
				Write-Host "$($target.computerDnsName) - Device Isolation - SUCCESS" -ForegroundColor Green
				$tagBody = @{
							Value = 'Isolated'
							Action = 'Add'
				
							}
				$tagUrl = "https://api.securitycenter.windows.com/api/machines/$($target.Id)/tags" 
				$tagResponse = Invoke-WebRequest -Method Post -Uri $tagUrl -Body ($tagBody|ConvertTo-Json) -Headers $headers -ErrorAction Stop
				
				If($tagResponse.StatusCode -eq "200")
					{Write-Host "$($target.computerDnsName) - Add Isolated Tag - SUCCESS" -ForegroundColor Green}
				else
					{Write-Host "$($target.computerDnsName) - Add Isolated Tag - FAIL" -ForegroundColor Red}
				}
			}
		}
	}
	
    Deploy-IsolateByTag
    # EXAMPLE: Deploy-IsolateByTag -targetTag "2BISO" -isolateType "Full" -isolateComment "IR9823"