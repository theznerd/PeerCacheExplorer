# Create a custom dialog window and add it to the main window
$SettingsDialog = [MahApps.Metro.Controls.Dialogs.CustomDialog]::new($formMainWindow)
$SettingsDialog.AddChild($formSettingsDialog)

# Show the dialog when settings is pressed
$formMainWindowControlSettingsButton.Add_Click({
    $settings             = [MahApps.Metro.Controls.Dialogs.MetroDialogSettings]::new()
    $settings.ColorScheme = [MahApps.Metro.Controls.Dialogs.MetroDialogColorScheme]::Theme 
    [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMetroDialogAsync($formMainWindow, $SettingsDialog, $settings)
})

# Close the dialog when cancel button pressed
$formSettingsDialogControlSettingsCancelButton.Add_Click({
    $SettingsDialog.RequestCloseAsync() 
})

# Use Alternate Credentials Button
$formSettingsDialogControlSettingsSetCredentials.Add_Click({
    try
    {
        $SyncClass.SyncHash.AlternateCredentials = (Get-Credential)
        $formSettingsDialogControlSettingsCredentialsName.Content = $SyncClass.SyncHash.AlternateCredentials.UserName
    }
    catch
    {
        $formSettingsDialogControlSettingsCredentialsName.Content = "(no credentials set)"
        $SyncClass.SyncHash.AlternateCredentials = $null
    }
})

# Save actions
$formSettingsDialogControlSettingsSaveButton.Add_Click({
    #New-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name PSDSSame -Value $formSettingsDialogControlSettingsCMDSSame.IsChecked -PropertyType String -Force | Out-Null
    #New-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name ConfigMgrPS -Value $formSettingsDialogControlSettingsCMPS.Text -PropertyType String -Force | Out-Null
    New-Item -Path "HKCU:\Software\Z-NERD\PCE\" -Force | Out-Null # Base Reg Key
    New-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name ConfigMgrDS -Value ($formSettingsDialogControlSettingsCMDS.Text) -PropertyType String -Force | Out-Null # Database server
    New-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name ConfigMgrSC -Value $formSettingsDialogControlSettingsCMSC.Text -PropertyType String -Force | Out-Null   # Site code
    New-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name UseAlternateCredentials -Value $formSettingsDialogControlSettingsUseCredentials.IsChecked -PropertyType String -Force | Out-Null # Use alternates
    # Only store credentials if checkbox is checked and credentials are set
    if($SyncClass.SyncHash.AlternateCredentials -and $formSettingsDialogControlSettingsUseCredentials.IsChecked)
    {
        New-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name UserName -Value $SyncClass.SyncHash.AlternateCredentials.UserName -PropertyType String -Force | Out-Null
        New-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name SecureString -Value (ConvertFrom-SecureString $SyncClass.SyncHash.AlternateCredentials.Password) -PropertyType String -Force | Out-Null
        $SyncClass.SyncHash.AlternateCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SyncClass.SyncHash.AlternateCredentials.UserName,$SyncClass.SyncHash.AlternateCredentials.Password
    }
    else # otherwise clear the values
    {
        $formSettingsDialogControlSettingsUseCredentials.IsChecked = $false
        $formSettingsDialogControlSettingsCredentialsName.Content = "(no credentials set)"
        $SyncClass.SyncHash.AlternateCredentials = $null
        New-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name UseAlternateCredentials -Value False -PropertyType String -Force | Out-Null
        New-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name UserName -Value "" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name SecureString -Value "" -PropertyType String -Force | Out-Null
        $SyncClass.SyncHash.AlternateCredentials = $null
    }
    #$SyncClass.SyncHash.ConfigMgrPS = $formSettingsDialogControlSettingsCMPS.Text      #Share primary site with background threads
    $SyncClass.SyncHash.ConfigMgrDS = $formSettingsDialogControlSettingsCMDS.Text       #Share database server with background threads
    # $SyncClass.SyncHash.PSDSSame = $formSettingsDialogControlSettingsCMDSSame.IsChecked #Share "shared database/site server" with background threads
    $SyncClass.SyncHash.ConfigMgrSC = $formSettingsDialogControlSettingsCMSC.Text       #Share site code with background threads
    $SyncClass.SyncHash.UseAlternateCredentials = $formSettingsDialogControlSettingsUseCredentials.IsChecked #Share shared credentials with background thread

    $SettingsDialog.RequestCloseAsync() # Close dialog
})

# Window Loaded
$formMainWindow.Add_Loaded({
    # Initialize Variables
    $SyncClass.SyncHash.AlternateCredentials = $null

    try
    {
        #$formSettingsDialogControlSettingsCMPS.Text = (Get-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name ConfigMgrPS -ErrorAction SilentlyContinue).ConfigMgrPS # Get primary server
        $formSettingsDialogControlSettingsCMDS.Text = (Get-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name ConfigMgrDS -ErrorAction SilentlyContinue).ConfigMgrDS # Get database server
        $formSettingsDialogControlSettingsCMSC.Text = (Get-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name ConfigMgrSC -ErrorAction SilentlyContinue).ConfigMgrSC # Get site code
        
        #$formSettingsDialogControlSettingsCMDSSame.IsChecked = [System.Convert]::ToBoolean((Get-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name PSDSSame -ErrorAction SilentlyContinue).PSDSSame)
        #if($formSettingsDialogControlSettingsCMDSSame.IsChecked)
        #{
        #    $formSettingsDialogControlSettingsCMDS.IsEnabled = $false
        #}
        
        #Convert creds checkbox from registry
        $formSettingsDialogControlSettingsUseCredentials.IsChecked = [System.Convert]::ToBoolean((Get-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name UseAlternateCredentials -ErrorAction SilentlyContinue).UseAlternateCredentials)
        
        #Load the credentials
        if($formSettingsDialogControlSettingsUseCredentials.IsChecked)
        {
            $UN = (Get-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name UserName -ErrorAction SilentlyContinue).UserName
            $SS = (Get-ItemProperty -Path "HKCU:\Software\Z-NERD\PCE\" -Name SecureString -ErrorAction SilentlyContinue).SecureString | ConvertTo-SecureString
            $formSettingsDialogControlSettingsCredentialsName.Content = $UN
            $SyncClass.SyncHash.AlternateCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UN,$SS
        }
        #$SyncClass.SyncHash.ConfigMgrPS = $formSettingsDialogControlSettingsCMPS.Text
        #$SyncClass.SyncHash.PSDSSame = $formSettingsDialogControlSettingsCMDSSame.IsChecked

        # Load variables to synchash to share with background threads
        $SyncClass.SyncHash.ConfigMgrDS = (&{if($formSettingsDialogControlSettingsCMDSSame.IsChecked){$formSettingsDialogControlSettingsCMPS.Text}else{$formSettingsDialogControlSettingsCMDS.Text}})
        $SyncClass.SyncHash.ConfigMgrSC = $formSettingsDialogControlSettingsCMSC.Text
        $SyncClass.SyncHash.UseAlternateCredentials = $formSettingsDialogControlSettingsUseCredentials.IsChecked
    }
    catch
    {
        Write-Warning "Error loading settings. Possibly first launch?"
    }
})

# Same DB/PS
#$formSettingsDialogControlSettingsCMDSSame.Add_Checked({
#    $formSettingsDialogControlSettingsCMDS.IsEnabled = $false
#    $formSettingsDialogControlSettingsCMDS.Text = $formSettingsDialogControlSettingsCMPS.Text
#})

#$formSettingsDialogControlSettingsCMDSSame.Add_Unchecked({
#    $formSettingsDialogControlSettingsCMDS.IsEnabled = $true
#})

#$formSettingsDialogControlSettingsCMPS.Add_TextChanged({
#    if($formSettingsDialogControlSettingsCMDSSame.IsChecked)
#    {
#        $formSettingsDialogControlSettingsCMDS.Text = $formSettingsDialogControlSettingsCMPS.Text
#    }
#})