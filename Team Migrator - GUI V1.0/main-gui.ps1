#========================================================
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
cd $PSScriptRoot
.".\functions.ps1"
add-type -AssemblyName System.Windows.Forms
$configpath = ".\config.json"
Add-Type -AssemblyName presentationframework, presentationcore
$wpf = @{ }
$inputXML = Get-Content -Path ".\mainwindow.xaml"
$inputXMLClean = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace 'x:Class=".*?"','' -replace 'd:DesignHeight="\d*?"','' -replace 'd:DesignWidth="\d*?"',''
[xml]$xaml = $inputXMLClean 
$xaml.GetType().FullName
$reader = New-Object System.Xml.XmlNodeReader $xaml
$tempform = [Windows.Markup.XamlReader]::Load($reader)
$namedNodes = $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")
$namedNodes | ForEach-Object {$wpf.Add($_.Name, $tempform.FindName($_.Name))}
#========================================================

#Code goes here:

#dictionary variables
$pointer = Get-message -key "pointer"
$general_invalid_input = Get-message -key "general_invalid_input"
$login_succes = Get-message -key "login_succes"
$login_failed = Get-message -key "login_failed"
$invalid_pat_for = Get-message -key "invalid_pat_for"
$invalid_pat = Get-message -key "invalid_pat"
$pat_paste = Get-message -key "pat_paste"
$invalid_org_name = Get-message -key "invalid_org_name"
$getting_projects = Get-message -key "getting_projects"
$invalid_organization_source = Get-message -key "error_on_organization_source"
$invalid_organization_target = Get-message -key "error_on_organization_source"
$get_teams = Get-message -key "get_teams"
$error_add_team = Get-message -key "error_add_team"
$init = Get-message -key "init"
$signin = Get-message -key "signin"
$decorlines = "=" * 35
$pat_success = Get-message -key "pat_success"
$pat_fail = Get-message -key "pat_fail"
$pat_verify_fail = Get-message -key "pat_verify_fail"
$out_s_org_verify = Get-message -key "out_s_org_verify"
$out_s_pro_verify = Get-message -key "out_s_pro_verify"
$out_s_team_verify = Get-message -key "out_s_team_verify"
$out_t_pro_verify = Get-message -key "out_t_pro_verify"
$out_t_team_verify = Get-message -key "out_t_team_verify"
$out_all_good = Get-message -key "out_all_good"
$migration_done = Get-message -key "migration_done"
$migration_error = Get-message -key "migration_error"
$successful_copies = Get-message -key "successful_copies"
$Failed_copies = Get-message -key "Failed_copies"
$Ignored_copies = Get-message -key "Ignored_copies"
#------------------------when terminal text is changed:
$wpf.TerminalTextBox.Add_TextChanged({
    $wpf.TerminalTextBox.ScrollToEnd();
})
#--------initialize------
#$wpf.StartButton.IsEnabled = $true <#for test#>
$wpf.ManualConfirmationCheck.IsEnabled = $false
$wpf.ManualConfirmationCheck.IsChecked = $true
$wpf.CreateLogFileCheck.IsEnabled = $false
$wpf.TerminalTextBox.IsReadOnly=$true
$wpf.ValidateButton.IsEnabled = $false
$wpf.ResetButton.IsEnabled = $false
$wpf.TerminalTextBox.AppendText("$($pointer+$init)")
$CHECK = CheckRequirements
$wpf.TerminalTextBox.AddText("$CHECK")
if($check -notmatch "is not installed")
    {$wpf.TerminalTextBox.AppendText("`n$($pointer+$signin)`n")}
#main variables
$global:source_org_name = $null
$global:source_org_address = $null
$global:source_org_project = $null
$global:source_org_team = $null
$global:target_org_name = $null
$global:target_org_address = $null
$global:target_org_project = $null
$global:target_org_team = $null
$global:signedin = $false
$global:out_target = $null
$global:out_pat = ''
$global:out_pat_verified = $false
$global:out_source_org_verified = $false
$global:out_source_pro_verified = $false
$global:out_source_team_verified = $false
$global:out_target_pro_verified = $false
$global:out_target_team_verified = $false
$global:reset_mode = 'clear'
#----------------------------------------------------

#when connect is clicked----------------------------------------------------
$wpf.ConnectButton.add_Click({
    $wpf.TerminalTextBox.AppendText("`n$($pointer)Connecting...`n") 
    az login 
    [System.Windows.Forms.Application]::DoEvents()
        try{
            $global:user = az account show --query user.name --output tsv
            if (IsValidEmail -EmailAddress $user -eq True) {
               $wpf.TerminalTextBox.AppendText("$($pointer+$login_succes+$user)`n")
               $wpf.ConnectButton.IsEnabled = $false
               $wpf.ConnectButton.Content = "Signed In"
               $wpf.ConnectButton.Foreground  = "#858585"
               $wpf.SourceOrgRefresh.IsEnabled = $true
               $wpf.TargetOrgRefresh.IsEnabled = $true
               $wpf.SourceOrgInput.IsEnabled = $true
               $wpf.TargetOrgInput.IsEnabled = $true
               Set-Variable global:signedin -Value $true
               $wpf.ResetButton.IsEnabled = $true
               
            }
            else {
                $wpf.TerminalTextBox.AppendText("$($pointer+$login_failed)`n")
                $wpf.TerminalTextBox.AppendText("$($pointer+$_)`n")
            }
        }
        catch{
            $wpf.TerminalTextBox.AppendText("$($pointer+$login_failed)`n")
            $wpf.TerminalTextBox.AppendText("$($pointer+$_)`n")
        }
})
#when paste is clicked-----------------------------------------------------
$wpf.PasteButton.add_Click({
    try{
     $global:clipboardContent = [System.Windows.Forms.Clipboard]::GetText()
     $wpf.PatTextBox.Clear()
     $wpf.PatTextBox.AddText($global:clipboardContent)
        if (!(PastePat $global:clipboardContent)){
        $wpf.TerminalTextBox.AppendText("$($pointer+"🚫 "+$invalid_pat_for+$global:clipboardContent)`n")
        }
        else {
        $wpf.PatTextBox.Clear()
        $wpf.PatTextBox.AddText("$($global:clipboardContent)`n")
        sleep -Milliseconds 200
        $wpf.TerminalTextBox.AppendText("$($pointer+"✅ "+$pat_paste)`n")
        sleep -Milliseconds 200
        Set-Variable -Name global:out_pat_verified -Value $true
        sleep -Milliseconds 200
        Set-Variable -Name global:out_pat -Value $global:clipboardContent
        
        }
    }
    catch{
     $wpf.TerminalTextBox.AppendText("$($pointer+"🚫 "+$invalid_pat)`n")
     $wpf.TerminalTextBox.AppendText("$($pointer+$_)`n")
    }
   
})
#when target organization text is changed--------------------------------
 $wpf.TargetOrgInput. Add_TextChanged({
    $wpf.TargetProjectInput.Items.Clear()
    $wpf.TargetTeamInput.Items.Clear()
    $wpf.TargetProjectInput.IsEnabled = $false
    $wpf.TargetTeamInput.IsEnabled = $false
    $wpf.ValidateButton.IsEnabled = $false
 })

 #when target organization text is changed--------------------------------
 $wpf.SourceOrgInput. Add_TextChanged({
    $wpf.sourceProjectInput.Items.Clear()
    $wpf.sourceTeamInput.Items.Clear()
    $wpf.sourceProjectInput.IsEnabled = $false
    $wpf.sourceTeamInput.IsEnabled = $false
 })
#when source organization refresh is clicked--------------------------------
$wpf.SourceOrgRefresh.add_Click({
    $wpf.SourceProjectInput.Items.Clear()
    $wpf.SourceTeamInput.Items.Clear()
    $wpf.SourceProjectInput.IsEnabled = $false
    $wpf.SourceTeamInput.IsEnabled = $false
    Set-Variable -Name global:source_org_name , global:source_org_address, global:source_org_project, global:source_org_team -value $null
    Start-Sleep -Milliseconds 200
    Set-Variable -Name global:source_org_name -value $wpf.SourceOrgInput.Text.ToString();
    try{
        if (!(CheckOrgName -str $global:source_org_name)){
            $wpf.TerminalTextBox.AddText("$($pointer+$invalid_org_name)`n")
            Set-Variable -Name global:out_source_org_verified -Value $false
        } 
        else {
                       
                        $global:source_org_address  = "https://dev.azure.com/$global:source_org_name/"
                        $az_source_org = az devops project list --org $global:source_org_address  --output json --query value[]."name" 
                        $az_source_org_list = [Regex]::Matches($az_source_org, '"(.*?)"')
                        $Source_org_valuesArray = @()
                        $wpf.TerminalTextBox.AddText("$($pointer+$getting_projects+$global:source_org_address)`n")
                          
                    foreach ($match in $az_source_org_list) {
                        $source_org_valuesArray += $match.Groups[1].Value
                    }
                        $source_org_valuesArray = $source_org_valuesArray | Sort-Object
                    foreach ($item in $source_org_valuesArray) {
                        $wpf.SourceProjectInput.AddText($item)
                    }
            $wpf.SourceProjectInput.IsEnabled = $true
            Set-Variable -Name global:out_source_org_verified -Value $true
                    
            }
        }
     catch {
        #$wpf.TerminalTextBox.AddText("$($pointer+$invalid_organization_source)`n")
        $wpf.TerminalTextBox.AddText("$($pointer+$invalid_organization_source)`n")
        $wpf.TerminalTextBox.AddText("$($pointer+$_)`n")
        }
})

#when target organization refresh is clicked--------------------------------
$wpf.TargetOrgRefresh.add_Click({
    $wpf.TargetProjectInput.Items.Clear()
    $wpf.TargetTeamInput.Items.Clear()
    $wpf.TargetProjectInput.IsEnabled = $false
    $wpf.TargetTeamInput.IsEnabled = $false
    Set-Variable -Name global:target_org_name , global:target_org_address, global:target_org_project, global:target_org_team -value $null
    Set-Variable -Name global:target_org_name -value $wpf.TargetOrgInput.Text.ToString();
    try{
        if (!(CheckOrgName -str $global:target_org_name)){
            $wpf.TerminalTextBox.AddText("$($pointer+$invalid_org_name)`n")
            $wpf.ValidateButton.IsEnabled = $false
        } 
        else {
                $wpf.TargetProjectInput.Items.Clear()
                $global:target_org_address  = "https://dev.azure.com/$global:target_org_name/"
                $az_target_org =  az devops project list --org $global:target_org_address  --output json --query value[]."name"
                $az_target_org_list = [Regex]::Matches($az_target_org, '"(.*?)"')
                $target_org_valuesArray = @()
                $wpf.TerminalTextBox.AddText("$($pointer+$getting_projects+$global:target_org_address)`n")
             foreach ($match in $az_target_org_list) {
                    $target_org_valuesArray += $match.Groups[1].Value
             }
                $target_org_valuesArray = $target_org_valuesArray | Sort-Object
             foreach ($item in $target_org_valuesArray) {
                    $wpf.TargetProjectInput.AddText($item)
             }
              $wpf.TargetProjectInput.IsEnabled = $true
            }
             Set-Variable -Name global:out_target -value $wpf.TargetOrgInput.Text.ToString();
             $wpf.ValidateButton.IsEnabled = $true

        }
        catch {$wpf.TerminalTextBox.AddText("$($pointer+$invalid_organization_target)`n")
               $wpf.TerminalTextBox.AddText("$($pointer+$_) - Invalid organization input`n")
               $wpf.ValidateButton.IsEnabled = $false
                }
        
})
 #when source project is selected--------------------------------
 $wpf.SourceProjectInput.add_SelectionChanged({
 $wpf.SourceTeamInput.Items.Clear()
  $wpf.SourceTeamInput.IsEnabled = $false
 Set-Variable -Name global:source_org_team -value $null
 Set-Variable -Name selected_source_project -value $wpf.SourceProjectInput.SelectedValue.ToString()
    if ($selected_source_project -eq $null){
        return $null
        Set-Variable -Name global:out_source_pro_verified -Value $false
    }
    else{
        try {
        $az_source_project = az devops team list --org $global:source_org_address --project  "$selected_source_project"  --output table --query [].name
    
            $wpf.TerminalTextBox.AddText("$($pointer+$get_teams+$selected_source_project)`n")
        
            $az_source_project[2..($az_source_project.Length)] | ForEach-Object {
                $wpf.SourceTeamInput.AddText("$($_)`n")
            }

            $wpf.SourceTeamInput.IsEnabled = $true
            Set-Variable -Name global:out_source_pro_verified -Value $true
            Set-Variable -Name global:source_org_project -Value $selected_source_project
        }
        catch {
            $wpf.TerminalTextBox.AddText("$($pointer+$error_add_team+$selected_source_project)`n")
            $wpf.TerminalTextBox.AddText("$($pointer+$_)`n")
    }
    }
})
 #when target project is selected--------------------------------
 $wpf.TargetProjectInput.add_SelectionChanged({
 $wpf.TargetTeamInput.Items.Clear()
 $wpf.TargetTeamInput.IsEnabled = $false
 Set-Variable -Name global:target_org_team -value $null
 Set-Variable -Name selected_target_project -value $wpf.TargetProjectInput.SelectedValue.ToString()
    
    if ($selected_target_project -eq $null){
        return $null
        Set-Variable -Name global:out_target_pro_verified -Value $false
        }
    else{
        try {
        $az_target_project = az devops team list --org $global:target_org_address --project  "$selected_target_project"  --output table --query [].name
    
            $wpf.TerminalTextBox.AddText("$($pointer+$get_teams+$selected_target_project)`n")
        
            $az_target_project[2..($az_target_project.Length)] | ForEach-Object {
                $wpf.TargetTeamInput.AddText("$($_)`n")
            }

            $wpf.TargetTeamInput.IsEnabled = $true
            Set-Variable -Name global:out_target_pro_verified -Value $true
            Set-Variable -Name global:target_org_project -Value $selected_target_project
        }
        catch {
            $wpf.TerminalTextBox.AddText("$($pointer+$error_add_team+$selected_target_project)`n")
            $wpf.TerminalTextBox.AddText("$($pointer+$_)`n")
        }
    }
})

 #when source team  is selected--------------------------------
 $wpf.SourceTeamInput.add_SelectionChanged({
  Set-Variable -Name selected_source_team -value $wpf.SourceTeamInput.SelectedValue.ToString()
  if ($selected_source_team -eq $null -or $selected_source_team -eq ''){
    Set-Variable -Name global:out_source_team_verified -Value $false
  }else{
    Set-Variable -Name global:out_source_team_verified -Value $true
    Set-Variable -Name global:source_org_team -Value $selected_source_team
  }
})

 #when target team  is selected--------------------------------
 $wpf.TargetTeamInput.add_SelectionChanged({
  Set-Variable -Name selected_target_team -value $wpf.TargetTeamInput.SelectedValue.ToString()
  if ($selected_target_team -eq $null -or $selected_target_team -eq ''){
    Set-Variable -Name global:out_target_team_verified -Value $false
  }else{
    Set-Variable -Name global:out_target_team_verified -Value $true
    Set-Variable -Name global:target_org_team -Value $selected_target_team
  }
})


#when validate is clicked--------------------------------
$wpf.ValidateButton.add_Click({
    
    
    
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $global:out_pat)))
    $global:headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", ("Basic {0}" -f $base64AuthInfo))
    $headers.Add("Content-Type", "application/json")
    $timeout = 30
   
    $validation = Invoke-RestMethod -Uri "https://dev.azure.com/$global:out_target/_apis/projects/?api-version=4.1" -Method GET -ContentType "application/json;charset=utf-8" -Headers $headers -TimeoutSec $timeout;
    $validation_result = if ($validation.count -lt 1 -or $validation -match "sign in"){$false}else{$true}
    switch ($false)
    {
    $validation_result {$wpf.TerminalTextBox.AddText("$($pointer+$pat_fail)`n")}
    $global:out_pat_verified {$wpf.TerminalTextBox.AddText("$($pointer+$pat_verify_fail)`n")} 
    $global:out_source_org_verified {$wpf.TerminalTextBox.AddText("$($pointer+$out_s_org_verify)`n")} 
    $global:out_source_pro_verified {$wpf.TerminalTextBox.AddText("$($pointer+$out_s_pro_verify)`n")}   
    $global:out_source_team_verified {$wpf.TerminalTextBox.AddText("$($pointer+$out_s_team_verify)`n")}  
    $global:out_target_pro_verified {$wpf.TerminalTextBox.AddText("$($pointer+$out_t_pro_verify)`n")}  
    $global:out_target_team_verified {$wpf.TerminalTextBox.AddText("$($pointer+$out_t_team_verify)`n")}  
        
        Default {
            $wpf.TerminalTextBox.AddText("$($pointer+$out_all_good)`n")
            $wpf.TerminalTextBox.AddText("$($pointer+$pat_success)`n")
            $wpf.PasteButton.IsEnabled = $false
            #--
            $wpf.SourceOrgInput.IsEnabled = $false
            $wpf.SourceProjectInput.IsEnabled = $false
            $wpf.SourceTeamInput.IsEnabled = $false
            #--
            $wpf.TargetOrgInput.IsEnabled = $false
            $wpf.TargetProjectInput.IsEnabled = $false
            $wpf.TargetTeamInput.IsEnabled = $false
            #--
            $wpf.SourceOrgRefresh.IsEnabled = $false
            $wpf.TargetOrgRefresh.IsEnabled = $false
            $wpf.ManualConfirmationCheck.IsEnabled = $true
            $wpf.CreateLogFileCheck.IsEnabled = $true
            $wpf.StartButton.IsEnabled = $true
            $wpf.ValidateButton.IsEnabled = $false
            
            Set-Variable -Name global:reset_mode -Value "reactivate"
            #--store to config:
            Set-Config -key "user" -value $global:user -path $configpath
            Set-Config -key "SourceOrg" -value $global:source_org_name -path $configpath
            Set-Config -key "SourceOrgAddress" -value $global:source_org_address -path $configpath
            Set-Config -key "SourceProject" -value $global:source_org_project -path $configpath
            Set-Config -key "SourceTeam" -value $global:source_org_team -path $configpath
            Set-Config -key "TargetOrg" -value $global:target_org_name -path $configpath
            Set-Config -key "TargetOrgAddress" -value $global:target_org_address -path $configpath
            Set-Config -key "TargetProject" -value $global:target_org_project -path $configpath
            Set-Config -key "TargetTeam" -value $global:target_org_team -path $configpath 
            Set-Config -key "isValidated" -value "true" -path $configpath
            Set-Config -key "PAT" -value $global:out_pat -path $configpath

        }    
    }
    

 
})

#when reset forms is clicked--------------------------------
$wpf.ResetButton.add_Click({
if ($global:reset_mode -eq 'clear'){
 $wpf.SourceOrgInput.Clear()
 $wpf.TargetOrgInput.Clear()
 $wpf.SourceProjectInput.Items.Clear()
 $wpf.TargetProjectInput.Items.Clear()
 $wpf.SourceTeamInput.Items.Clear()
 $wpf.TargetTeamInput.Items.Clear()
 #--
 $wpf.SourceProjectInput.IsEnabled = $false
 $wpf.SourceTeamInput.IsEnabled = $false
 $wpf.TargetProjectInput.IsEnabled = $false
 $wpf.TargetTeamInput.IsEnabled = $false
 $wpf.ManualConfirmationCheck.IsEnabled = $false
 $wpf.CreateLogFileCheck.IsEnabled = $false
 $wpf.StartButton.IsEnabled = $false
 $wpf.PasteButton.IsEnabled = $true
 #--
 #--
 Set-Variable -Name global:out_source_org_verified , global:out_source_pro_verified, global:out_source_team_verified -value $false
 Set-Variable -Name global:out_target_pro_verified , global:out_target_team_verified -value $false
}else {
            $wpf.PasteButton.IsEnabled = $true
            $wpf.ValidateButton.IsEnabled = $true
            #--
            $wpf.SourceOrgInput.IsEnabled = $true
            $wpf.SourceProjectInput.IsEnabled = $true
            $wpf.SourceTeamInput.IsEnabled = $true
            #--
            $wpf.TargetOrgInput.IsEnabled = $true
            $wpf.TargetProjectInput.IsEnabled = $true
            $wpf.TargetTeamInput.IsEnabled = $true
            #--
            $wpf.SourceOrgRefresh.IsEnabled = $true
            $wpf.TargetOrgRefresh.IsEnabled = $true
            $wpf.ManualConfirmationCheck.IsEnabled = $false
            $wpf.CreateLogFileCheck.IsEnabled = $false
            $wpf.StartButton.IsEnabled = $false
            Set-Variable -Name global:reset_mode -Value "clear"
}
})
#---------------Start Button-------------------
$wpf.StartButton.add_Click({
  $get_date = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"
  
  #$wpf.TerminalTextBox.AddText("start button is working`n")

  if ($wpf.CreateLogFileCheck.IsChecked) {Set-Config -key "CreateLog" -value 'true' -path $configpath} else {Set-Config -key "CreateLog" -value 'false' -path $configpath}
  if ($wpf.ManualConfirmationCheck.IsChecked) {Set-Config -key "ManualConfirmation" -value 'true' -path $configpath} else {Set-Config -key "ManualConfirmation" -value 'false' -path $configpath}
  Set-Config -key "dateStarted" -value $get_date -path $configpath
  # Run the script in a new window and wait for it to complete
  try{
    
    & .\TeamMigrator.ps1
    $wpf.TerminalTextBox.AddText("☑️ "+"$migration_done`n")
    Start-Sleep -Milliseconds 500
    $SU = Get-Config "SU";
    $FU = Get-Config "FU";
    $IU = Get-Config "IU";
    Switch(0){
    
    {$SU -ne '0'}{$wpf.TerminalTextBox.AddText("$successful_copies $SU `n")}
    {$FU -ne '0'}{$wpf.TerminalTextBox.AddText("$Failed_copies $FU `n")}
    {$IU -ne '0'}{$wpf.TerminalTextBox.AddText("$Ignored_copies $SU `n")}
    }
     }
  catch{
    
    $wpf.TerminalTextBox.AddText("❎ "+"$migration_error`n $_")

     }
  
  
})
#------------Open Log Folder button-------------
$wpf.OpenLogButton.add_Click({
    ii .\log
})

#========================================================
$wpf.MainWindowMigrator.ShowDialog() | Out-Null


