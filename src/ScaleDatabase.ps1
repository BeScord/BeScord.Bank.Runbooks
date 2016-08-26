param (     
	[object]$webhookData 
)

if ($webhookData -ne $null) {
	$webhookBody = $webhookData.RequestBody 
	$webhookHeaders = $webhookData.RequestHeader 

    $webhookBody = (ConvertFrom-Json -InputObject $webhookBody) 
    $alertContext = [object]$webhookBody.context

	$connectionName = "AzureRunAsConnection"
	try
	{
	   # Get the connection "AzureRunAsConnection "
	   $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

	   "Logging in to Azure..."
	   Add-AzureRmAccount `
	     -ServicePrincipal `
	     -TenantId $servicePrincipalConnection.TenantId `
	     -ApplicationId $servicePrincipalConnection.ApplicationId `
	     -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 

	   "Setting context to a specific subscription"  
	   Set-AzureRmContext -SubscriptionId $alertContext.subscriptionId             
	}
	catch {
	    if (!$servicePrincipalConnection)
	    {
	       $ErrorMessage = "Connection $connectionName not found."
	       throw $ErrorMessage
	     } else{
	        Write-Error -Message $_.Exception
	        throw $_.Exception
	     }
	} 

	$sqlServerAndDatabaseNames = $alertContext.resourceId.Split('/')
	$sqlServerName = $sqlServerAndDatabaseNames[$sqlServerAndDatabaseNames.Length - 3]
	$sqlDatabaseName = $sqlServerAndDatabaseNames[$sqlServerAndDatabaseNames.Length - 1]
	
	if ($alertContext.description -eq $null -or !$alertContext.description.Contains("/")) {
		Write-Error "The description of the alert should tell what edition and size to switch to (eg. Premium/P4)"
		return
	}
	
	$sqlEditionAndSize = $alertContext.description.Split('/')
	$sqlEdition = $sqlEditionAndSize[0]
	$sqlSize = $sqlEditionAndSize[1]
	
	Write-Output "Scaling $sqlServerName/$sqlDatabaseName to $sqlEdition/$sqlSize"
	
	Set-AzureRmSqlDatabase -ResourceGroupName $alertContext.resourceGroupName -ServerName $sqlServerName -DatabaseName $sqlDatabaseName -Edition $sqlEdition -RequestedServiceObjectiveName $sqlSize
} 
else  
{ 
    Write-Error "This runbook is meant to only be started from a webhook."
} 