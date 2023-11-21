# NOTE: This script needs Join-Module -- to install it run the code below in powershell using admin rights:
# Install-Module -Name JoinModule
# full documentation is here: https://github.com/iRon7/Join-Object
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
cd $PSScriptRoot
.".\functions.ps1"
# CONFIG INPUTS:
    $isvlaidated = Get-Config "isValidated"
	$pat = Get-Config "PAT"
    $username = Get-Config "user"
    $createlogfile = Get-Config "CreateLog"
    $manualconfirm = Get-Config "ManualConfirmation"
    $dateStarted = Get-Config "dateStarted"
    $dateFinished = Get-Config "dateFinished"
# Source Inputs:
	$SourceCollection = Get-Config "SourceOrg"; #source organization
	$SourceProject = Get-Config "SourceProject";
	$SourceTeam = Get-Config "SourceTeam";
    $SourceTeam = $SourceTeam.replace("`n","")
# Target Inputs:
	$Collection = Get-Config "TargetOrg";
	$Project = Get-Config "TargetProject";
	$TargetTeam = Get-Config "TargetTeam";
    $TargetTeam = $TargetTeam.replace("`n","")
#az login
#----System Parameters--------------------------------------------------------------------
$configpath = ".\config.json"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $pat)))
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", ("Basic {0}" -f $base64AuthInfo))
$headers.Add("Content-Type", "application/json")
$CollectionAddress = 'https://dev.azure.com/'+$Collection;
$SourceCollectionAddress = 'https://dev.azure.com/'+$SourceCollection;
$Timeout = 30;
# List source team members and extract user IDs using Azure CLI
az devops team list-member --org $SourceCollectionAddress --project $SourceProject --team $SourceTeam --output table --query "[].{uniqueName:identity.uniqueName}" > temp\SourceTeamMembers.txt
Import-CSV -Delimiter "`t" -Path temp\SourceTeamMembers.txt | Export-Csv -Path temp\SourceTeamMembers.csv -NoTypeInformation # Convert the output file to CSV format
# List target team members and extract user IDs using Azure CLI
az devops team list-member --org $CollectionAddress --project $Project --team $TargetTeam --output table --query "[].{uniqueName:identity.uniqueName}" > temp\TargetTeamMembers.txt
Import-CSV -Delimiter "`t" -Path temp\TargetTeamMembers.txt | Export-Csv -Path temp\TargetTeamMembers.csv -NoTypeInformation # Convert the output file to CSV format

Remove-Item -Path "temp\TargetTeamMembers.txt", "temp\SourceTeamMembers.txt" # Remove the temporary output files
###########################Inner Join the CSV files to remove the exisiting users from script#########
$members = @()
$sourcemembers = Import-Csv temp\SourceTeamMembers.csv | Select-Object -Skip 1
$targetmembers = Import-Csv temp\TargetTeamMembers.csv | Select-Object -Skip 1

foreach ($i in $sourcemembers.UniqueName){
    if ($i -in $targetmembers.UniqueName){
    continue}
    else{
    $members += $i
    }
}
#####
Write-Host "----------------------------------------------"
Write-Host "List of memebers to be moved to the '$TargetTeam'"
foreach ($o in $members){

    Write-Host $o
}
Write-Host "----------------------------------------------"
########################## Getting the Target Team Info ##########################
# Get Target Project ID
$ProjectId = (Invoke-RestMethod -Uri "https://dev.azure.com/$($Collection)/_apis/projects/$($Project)?api-version=6.0" -Method GET -ContentType "application/json;charset=utf-8" -Headers $Headers -TimeoutSec $Timeout).id;
Write-Host "ProjectId: $ProjectId";

# Get Target Project Descriptor
$ProjecDescriptor = (Invoke-RestMethod -Uri "https://vssps.dev.azure.com/$($Collection)/_apis/graph/descriptors/$($ProjectId)?api-version=6.0-preview" -Method GET -ContentType "application/json;charset=utf-8" -Headers $Headers -TimeoutSec $Timeout).value;
Write-Host "ProjecDescriptor: $ProjecDescriptor";

# Get Teams in the Target Project:
$TeamsInProject = (Invoke-RestMethod -Uri "https://vssps.dev.azure.com/$($Collection)/_apis/graph/groups?scopeDescriptor=$($ProjecDescriptor)&api-version=6.0-preview" -Method GET -ContentType "application/json;charset=utf-8" -Headers $Headers -TimeoutSec $Timeout).value;
#Write-Host "TeamsInProject: $($TeamsInProject | forEach { "`n - $($_.displayName) : $($_.descriptor)" }) `n";

# Get the Target Team:
$Team = $TeamsInProject | Where-Object { $_.displayName -eq $TargetTeam -and $_.descriptor -match 'vssgp'} #note that the 'vssgp' filter is added to get the team only, and not the AAD group
Write-Host "Team: $($Team.displayName) : $($Team.descriptor)";

#####################################Get User Name from API: 
$MovedNumber = 0;
$FailedNumber = 0;
$IgnoredNumber = 0;
$lines = "-" * 35
$lines_long = "-" * 87
$_tempfailedusers = "";
$_tempignoredusers = "";
$_tempaddedusers = "";
foreach ($member in $members) {
	$Email = $member
	if ($Email -match "vstfs" -or $Email -eq "" -or $Email -eq $null) {
        Write-Host "××× Object ignored ×××"
		$_tempignoredusers += "$($Email) - The object is a group. Groups migration is not supported yet.`n"
		$IgnoredNumber +=1
    } else {
        $User = (Invoke-RestMethod -Uri "https://vsaex.dev.azure.com/$($Collection)/_apis/userentitlements?api-version=5.1-preview.2&filter=name eq $($Email)" -Method GET -ContentType "application/json;charset=utf-8" -Headers $headers ).members[0];
			if ($User.user.displayName	-eq "" -or $User.user.displayName -eq $null) {
				Write-Host "××× Object ignored - Reason: no display name or the object is a group (group migration is not supported) ×××"
				$IgnoredNumber +=1
			} else {
				Write-Host "User to add to the team:" $User.user.displayName	
				$body = @{
				"originId" = $User.user.originId
				};
                if ($manualconfirm -eq $false){
                    #$prompt = Read-Host -Prompt "auto confirm is active...TEST"
					try {
						$result = (Invoke-RestMethod -Uri "https://vssps.dev.azure.com/$($Collection)/_apis/graph/Users?groupDescriptors=$($Team.descriptor)&api-version=6.0-preview" -Method POST -ContentType "application/json;charset=utf-8" -Headers $Headers -Body $($body | ConvertTo-Json -Depth 10 -Compress) -TimeoutSec $Timeout)
						Write-Host '*** '$User.user.displayName 'Added successfully ***'
						$MovedNumber += 1
						$AddedUser = "$($User.user.displayName) <$($User.user.principalName)>" 
						$_tempaddedusers += "$($AddedUser)`n"
						}
					catch {
						Write-Host "××× An error occurred. Please add $($User.user.displayName) manually`n" 
                        Write-Host "$_"
						$FailedUser = "$($User.user.displayName) <$($User.user.principalName)>" 
						$FailedNumber += 1
						$_tempfailedusers += "$($FailedUser)`n"
						}}
               else{
                   $prompt = Read-Host -Prompt "Do you want to add the user? Press (Y) for Yes, (N) for No."
                        if ($prompt -eq 'Y' -or $prompt -eq 'y'){
                                try {           
                                    $result = (Invoke-RestMethod -Uri "https://vssps.dev.azure.com/$($Collection)/_apis/graph/Users?groupDescriptors=$($Team.descriptor)&api-version=6.0-preview" -Method POST -ContentType "application/json;charset=utf-8" -Headers $Headers -Body $($body | ConvertTo-Json -Depth 10 -Compress) -TimeoutSec $Timeout)
						            Write-Host '*** '$User.user.displayName 'Added successfully ***'
						            $MovedNumber += 1
						            $AddedUser = "$($User.user.displayName) <$($User.user.principalName)>" 
						            $_tempaddedusers += "$($AddedUser)`n"
						        }
					            catch {
						            Write-Host "××× An error occurred. Please add $($User.user.displayName) manually`n" 
                                    Write-Host "$_"
						            $FailedUser = "$($User.user.displayName) <$($User.user.principalName)>" 
						            $FailedNumber += 1
						            $_tempfailedusers += "$($FailedUser)`n"
						        }
                            }
                        elseif ($prompt -eq 'N' -or $prompt -eq 'n'){
                        $IgnoredNumber +=1
                        $IgnoredUser = "$($User.user.displayName) <$($User.user.principalName)> - User skipped" 
                        Write-Host '××× '$User.user.displayName 'is skipped ×××'
                        $_tempignoredusers += "$($IgnoredUser)`n"
                        }
                        else{
                        $IgnoredNumber +=1
                        $IgnoredUser = "$($User.user.displayName) <$($User.user.principalName)> - User skipped by pressing the wrong input for confirmation" 
                        $_tempignoredusers += "$($IgnoredUser)`n"
                        Write-Host '××× '$User.user.displayName 'is skipped ×××'
                        }
                   }
               }
 
		   }
    }
#######Creating Log##################################################################
$time = Get-Date
$time_for_file = Get-Date -Format "MMddyyyy-HHmmss"
      Set-Config -key "SU" -value $MovedNumber -path $configpath 
      Set-Config -key "FU" -value $FailedNumber -path $configpath
      Set-Config -key "IU" -value $IgnoredNumber -path $configpath
      Set-Config -key "dateFinished" -value $time -path $configpath
$table = 
switch ("")
{
	{$_tempfailedusers.Length -ne 0}{"$($lines)Failed Users$($lines)`n"+$_tempfailedusers+"`n ⚠️ User migration fails mostly because the user does not exist anymore in the domain.`nTo confirm if the user exists you can use the following command: az ad user show --id <user email>`n$lines_long`n"}
	{$_tempignoredusers.Length -ne 0}{"$($lines)Ignored Objects$($lines)`n"+$_tempignoredusers}
	{$_tempaddedusers.Length -ne 0}{"$($lines)Added Users$($lines)`n"+$_tempaddedusers}
}
$logbody = 
@"
Time:	$($time)
Source Team:	'$($SourceTeam)' from $($SourceCollectionAddress)/$($SourceProject)'
Target Team:	'$($TargetTeam)' from $($CollectionAddress)/$($Project)'
$($lines_long)
Successful	|	$($MovedNumber)
Ignored		|	$($IgnoredNumber)
Failed		|	$($FailedNumber)
$($table)
"@;
if ($createlogfile -eq $true){
    New-Item -ItemType "file" -Path "log\MigrationLogFile_$($time_for_file ).log" -value $logbody -force | Out-Null;}
   else{Write-Host ""}
Write-Host "*** Migration is done ***"
Remove-Item -Path temp\SourceTeamMembers.csv, temp\TargetTeamMembers.csv

