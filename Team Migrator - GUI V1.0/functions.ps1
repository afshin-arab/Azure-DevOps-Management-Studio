#------------------------------------------
$dict_path = ".\dict.json" 
function Get-message ([string]$key) {
    $_ = Get-Content -Raw -Path $dict_path | ConvertFrom-Json
    $_.$key
}
#------------------------------------------
function CheckRequirements (){
 $message = ''

    if(Get-Module -ListAvailable -Name JoinModule){$message += "`n> Join Module is installed"
    }else{
        $message += "`n> Join Module is not installed - please import it using: Import-Module JoinModule command"
        }
    try{az --version | Out-Null
        $message += "`n> Azure CLI is installed - no further action is required"
        }
    catch{
        $message += "`n> Azure CLI is not installed - please install it from Microsoft's website"
        }
    RETURN $message
}
#------------------------------------------
function SetVariableBulk {
    Param(
    [string[]]$VariableNames,
    [string]$NewValue
    )
    foreach ($VarName in $VariableNames) {
       Set-Variable -Name $VarName -Value $NewValue -Scope Global
       Write-Host "$VarName set to: $NewValue"
      }
    
}
#------------------------------------------
function CheckOrgName
{
    Param
    (
    [string]$str
    )
    $str = $str.TrimStart().TrimEnd()
    if ($str  -notmatch "^[a-zA-Z0-9._-].{0,48}[a-zA-Z0-9._-]$" -or $str -eq $null -or $str -match '--' -or $str -match '__') {$false}
        elseif($str -like '*_' -or $str -like '_*'-or $str -like '*-'-or $str -like '-*') {$false}
        else{$true}
}
#------------------------------------------
function IsValidEmail { 
    param([string]$EmailAddress)

    try {
        $null = [mailaddress]$EmailAddress
        return $true
        
    }
    catch {
        return $false
        
    }
}
#------------------------------------------
function PastePAT {
    param(
    [string]$pat
    )
    if (!($pat.Length -eq 52) -or $pat -notmatch "^[a-zA-Z0-9]{52}$") {
        $false
    }else{
        $true
    }
}
#------------------------------------------
function ValidatePAT {
    param (
    [string]$pat , 
    [string]$org)
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $pat)))
    $global:headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", ("Basic {0}" -f $base64AuthInfo))
    $headers.Add("Content-Type", "application/json")
    $timeout = 30
   
    $validation = Invoke-RestMethod -Uri "https://dev.azure.com/$org/_apis/projects/?api-version=4.1" -Method GET -ContentType "application/json;charset=utf-8" -Headers $headers -TimeoutSec $timeout;
    if ($validation.count -lt 1){
       return 0
    }else{
       return 1
    }
    
}
#------------------------------------------
function Set-Config {
  param (
    [string] $key,
    [string] $value,
    [string] $path
  )

  # Read the JSON file and convert it to a PowerShell object
  $jsonObject = Get-Content -Raw $path | ConvertFrom-Json

  # Add or modify the property with the given value
  $jsonObject | Add-Member -Type NoteProperty -Name $key -Value $value -Force

  # Convert the object back to JSON and save it to the file
  $jsonObject | ConvertTo-Json | Set-Content $path
}

function Get-Config ([string]$key) {
    $_ = Get-Content -Raw -Path ".\config.json"  | ConvertFrom-Json
    return $_.$key
}






