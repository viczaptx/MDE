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

Function Remove-IsolateByTag {

    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$targetTag
        )

	# GET COMPUTER ID BY TAG
	$machineUrl = "https://api.securitycenter.microsoft.com/api/machines?"
	$machines = ((Invoke-WebRequest -Method Get -Uri $machineUrl -Headers $headers -ErrorAction Stop).Content | ConvertFrom-Json).value
	$targetMachines = $machines | ?{$_.machineTags -match "$targetTag$"}

    if($targetMachines -eq $null)
        {Write-Host "No Devices Found with $targetTag Tag" -ForegroundColor Red}
    else
        {
        $devCount = ($targetMachines.id).count
        Write-Host "$devCount Device/s Found with $targetTag Tag" -ForegroundColor Cyan

		# LOOP THROUGH EACH TARGET MACHINE
		forEach ($target in $targetMachines)
			{
			$machineUrl = "https://api.securitycenter.microsoft.com/api/machines/$($target.Id)"
			$machineResponse = Invoke-WebRequest -Method Get -Uri $machineUrl -Headers $headers -ErrorAction Stop 
			Write-Host "$($target.computerDnsName)" -ForegroundColor Yellow
			Write-Host "$($target.Id)" -ForegroundColor Yellow

			# REMOVE ISOLATION FROM TARGET DEVICE BY ID
			$unisolateURL = "https://api.securitycenter.microsoft.com/api/machines/$($target.Id)/unisolate"
			$unisolateBody = @{
				Comment = 'UnIsolate machine'
				}
			$unisolateResponse = Invoke-WebRequest -Method Post -Uri $unisolateURL -Body ($unisolateBody|ConvertTo-Json) -Headers $headers -ErrorAction Stop

			# REMOVE 'ISOLATED' TAG FROM TARGET MACHINE
			if ($unisolateResponse.StatusCode -eq "201")
				{
				Write-Host "$($target.computerDnsName) - Device Release Isolation - SUCCESS" -ForegroundColor Green
				$tagBody = @{
							Value = 'Isolated';
							Action = 'Remove';
							}

				$tagUrl = "https://api.securitycenter.windows.com/api/machines/$($target.Id)/tags" 
				$tagResponse = Invoke-WebRequest -Method Post -Uri $tagUrl -Body ($tagBody1|ConvertTo-Json) -Headers $headers -ErrorAction Stop

					If($tagResponse.StatusCode -eq "200")
						{Write-Host "$($target.computerDnsName) - Remove Isolated Tag - SUCCESS" -ForegroundColor Green}
					else
						{Write-Host "$($target.computerDnsName) - Remove Isolated Tag - FAIL" -ForegroundColor Red}
			    }
			else
				{Write-Host "$($target.computerDnsName) - Device Release Isolation - FAIL" -ForegroundColor Red}
			}
		}
    }

Remove-IsolateByTag
# EXAMPLE: Remove-IsolateByTag -targetTag "2BISO"