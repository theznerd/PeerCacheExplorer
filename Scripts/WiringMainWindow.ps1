# Create the datagrid observable collection (for filtering)
$SyncClass.SyncHash.DataGridList = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$SyncClass.SyncHash.DataGridListLock = New-Object PSObject
$SyncClass.SyncHash.DataGridView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($SyncClass.SyncHash.DataGridList)
$formMainWindowControlContentDataGrid.ItemsSource = $SyncClass.SyncHash.DataGridView

# Create a binding for the datagrid to the observable collection
$DataGridListBinding = New-Object System.Windows.Data.Binding
$DataGridListBinding.Source = $SyncClass.SyncHash.DataGridList
$DataGridListBinding.Mode = [System.Windows.Data.BindingMode]::OneWay
[void][System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($SyncClass.SyncHash.DataGridList,$SyncClass.SyncHash.DataGridListLock)
[void][System.Windows.Data.BindingOperations]::SetBinding($formMainWindowControlContentDataGrid,[System.Windows.Controls.ListBox]::ItemsSourceProperty, $DataGridListBinding)

# Allow action when package or superpeer selected
$SyncClass.SyncHash.ActOnPackage = $true
$SyncClass.SyncHash.ActOnSuperPeer = $true

# Filtering when text is changed
$formMainWindowControlSuperPeerSearch.Add_TextChanged({
    $SyncClass.SyncHash.SuperPeerView.Filter = {$args[0].Name00 -match $this.Text}
})

# Filtering when text is changed
$formMainWindowControlPackageSearch.Add_TextChanged({
    $SyncClass.SyncHash.AppPkgView.Filter = {$args[0].Name -match $this.Text}
})

# Filtering when text is changed
$formMainWindowControlDataGridFilter.Add_TextChanged({
    $SyncClass.SyncHash.DataGridView.Filter = {$args[0] -match $this.Text}
})

# When a selection is made for a SuperPeer
$formMainWindowControlSuperPeerListBox.Add_SelectionChanged({
    # Make sure we want to act - so that we don't do double queries and confuse the app... threading is fun :)
    if($SyncClass.SyncHash.ActOnSuperPeer -and $SyncClass.SyncHash.ActOnAny)
    {
        # Keep user from making changes accidentally
        $formMainWindowControlLoadingOverlay.Visibility = "Visible"
        $formMainWindowControlRefreshButton.IsEnabled = $false
        
        # Deselect any selected package without acting on it
        $SyncClass.SyncHash.ActOnPackage = $false
        $formMainWindowControlPackageListBox.SelectedIndex = -1
        $SyncClass.SyncHash.ActOnPackage = $true

        # Clear the datagrid
        $SyncClass.SyncHash.DataGridList.Clear()
        $SyncClass.UpdateElement("formMainWindowControlLoadingText","Content","Loading Applications/Packages on SuperPeer")

        # Sync the selected item
        $SyncClass.SyncHash.SelectedItem = $formMainWindowControlSuperPeerListBox.SelectedItem

        # Let's do this in the background because it will take some time
        Start-BackgroundScriptBlock -scriptBlock {
            try{
                $spCommand = @{ 
                    'SqlInstance' = $SyncClass.SyncHash.ConfigMgrDS 
                    'Database' = "CM_$($SyncClass.SyncHash.ConfigMgrSC)"
                }
                if($SyncClass.SyncHash.AlternateCredentials){$spCommand['SqlCredential'] = $SyncClass.SyncHash.AlternateCredentials}
                elseif($spCommand['SqlCredential']){ $spCommand.Remove('SqlCredential') }
                
                #Get applications for selected system
                $Query = "USE CM_$($SyncClass.SyncHash.ConfigMgrSC); SELECT SP.ResourceID,CS.Domain00,CS.Name00,SP.ContentID,SP.Version FROM SuperPeerContentMap as SP `
                    INNER JOIN vSMS_CIToContent as CI on SP.ContentID = CI.Content_UniqueID `
                    INNER JOIN fn_ListDeploymentTypeCIs(1033) as LCI on LCI.CI_ID = CI.CI_ID `
                    INNER JOIN fn_ListApplicationCIs(1033) as LAC on LAC.ModelName = LCI.AppModelName `
                    INNER JOIN Computer_System_DATA as CS on CS.MachineID = SP.ResourceID `
                    WHERE ResourceID = $($SyncClass.SyncHash.SelectedItem.ResourceID)"
                $Applications = @()
                $Applications += (Connect-DbaInstance @spCommand).Query($Query)
                
                #Add applications to the grid
                foreach($a in $Applications)
                {
                    $obj = [PSCustomObject]@{
                        Name = $a.Name00
                        Domain = $a.Domain00
                        ResourceID = $a.ResourceID
                        ContentID = $a.ContentID
                        Version = $a.Version
                    }
                    $SyncClass.SyncHash.DataGridList.add($obj)
                }

                $spCommand = @{ 
                    'SqlInstance' = $SyncClass.SyncHash.ConfigMgrDS 
                    'Database' = "CM_$($SyncClass.SyncHash.ConfigMgrSC)"
                }
                if($SyncClass.SyncHash.AlternateCredentials){$spCommand['SqlCredential'] = $SyncClass.SyncHash.AlternateCredentials}
                elseif($spCommand['SqlCredential']){ $spCommand.Remove('SqlCredential') }
                
                #Get packages for selected system
                $Query = "USE CM_$($SyncClass.SyncHash.ConfigMgrSC); SELECT SP.ResourceID,CS.Name00,CS.Domain00,SP.ContentID,SP.Version FROM SuperPeerContentMap as SP `
                    INNER JOIN SMSPackages_All as PL on SP.ContentID = PL.PkgID `
                    INNER JOIN Computer_System_DATA as CS on CS.MachineID = SP.ResourceID `
                    WHERE SP.ResourceID = $($SyncClass.SyncHash.SelectedItem.ResourceID)"
                $Packages = @()
                $Packages += (Connect-DbaInstance @spCommand).Query($Query)
                
                #Add packages to the grid
                foreach($p in $Packages)
                {
                    $obj = [PSCustomObject]@{
                        Name = $p.Name00
                        Domain = $p.Domain00
                        ResourceID = $p.ResourceID
                        ContentID = $p.ContentID
                        Version = $p.Version
                    }
                    $SyncClass.SyncHash.DataGridList.add($obj)
                }

                #Clear the filter
                $SyncClass.UpdateElement("formMainWindowControlDataGridFilter","Text","")
            }
            catch
            {
                [System.Windows.Messagebox]::Show("There was an error getting info from the database. Does the account have the appropriate read permissions to the ConfigMgr Database?","ERROR In DB Query")
            }
            
            # Allow the user to click around again
            $SyncClass.UpdateElement("formMainWindowControlLoadingOverlay","Visibility","Collapsed")
            $SyncClass.UpdateElement("formMainWindowControlRefreshButton","IsEnabled",$true)
        }
    }
})

# When a selection is made for a Package/App
$formMainWindowControlPackageListBox.Add_SelectionChanged({
    #Only act if we should
    if($SyncClass.SyncHash.ActOnPackage -and $SyncClass.SyncHash.ActOnAny)
    {
        # User NO TOUCHY
        $formMainWindowControlLoadingOverlay.Visibility = "Visible"
        $formMainWindowControlRefreshButton.IsEnabled = $false
        
        # Clear any selections on the super peer
        $SyncClass.SyncHash.ActOnSuperPeer = $false
        $formMainWindowControlSuperPeerListBox.SelectedIndex = -1
        $SyncClass.SyncHash.ActOnSuperPeer = $true

        # Clear the datagrid
        $SyncClass.SyncHash.DataGridList.Clear()
        $SyncClass.UpdateElement("formMainWindowControlLoadingText","Content","Loading SuperPeers with Application/Package")

        # Share the selected item with background threads
        $SyncClass.SyncHash.SelectedItem = $formMainWindowControlPackageListBox.SelectedItem

        # Let's do this in the background
        Start-BackgroundScriptBlock -scriptBlock {
            $sqlServer = $SyncClass.SyncHash.ConfigMgrDS
            $database = $SyncClass.SyncHash.ConfigMgrSC

            try{
                # If an application was selected
                if($($SyncClass.SyncHash.SelectedItem.ContentID) -like "Content_*")
                {
                    
                    $spCommand = @{ 
                        'SqlInstance' = $SyncClass.SyncHash.ConfigMgrDS 
                        'Database' = "CM_$($SyncClass.SyncHash.ConfigMgrSC)"
                    }
                    if($SyncClass.SyncHash.AlternateCredentials){$spCommand['SqlCredential'] = $SyncClass.SyncHash.AlternateCredentials}
                    elseif($spCommand['SqlCredential']){ $spCommand.Remove('SqlCredential') }
                    
                    # Query to get devices used by application
                    $Query = "USE CM_$($SyncClass.SyncHash.ConfigMgrSC); SELECT SP.ResourceID,CS.Name00,CS.Domain00,SP.ContentID,SP.Version FROM SuperPeerContentMap as SP `
                        INNER JOIN vSMS_CIToContent as CI on SP.ContentID = CI.Content_UniqueID `
                        INNER JOIN fn_ListDeploymentTypeCIs(1033) as LCI on LCI.CI_ID = CI.CI_ID `
                        INNER JOIN fn_ListApplicationCIs(1033) as LAC on LAC.ModelName = LCI.AppModelName `
                        INNER JOIN Computer_System_DATA as CS on CS.MachineID = SP.ResourceID `
                        WHERE SP.ContentID = '$($SyncClass.SyncHash.SelectedItem.ContentID)' `
                        ORDER BY CS.Name00"
                    $Applications = @()
                    $Applications += (Connect-DbaInstance @spCommand).Query($Query)

                    # Add devices to the grid that have the application
                    foreach($a in $Applications)
                    {
                        $obj = [PSCustomObject]@{
                            ResourceID = $a.ResourceID
                            Name = $a.Name00
                            Domain = $a.Domain00
                            ContentID = $a.ContentID
                            Version = $a.Version
                        }
                        $SyncClass.SyncHash.DataGridList.add($obj)
                    }
                }
                else # Package was selected
                {
                    $spCommand = @{ 
                        'SqlInstance' = $SyncClass.SyncHash.ConfigMgrDS 
                        'Database' = "CM_$($SyncClass.SyncHash.ConfigMgrSC)"
                    }
                    if($SyncClass.SyncHash.AlternateCredentials){$spCommand['SqlCredential'] = $SyncClass.SyncHash.AlternateCredentials}
                    elseif($spCommand['SqlCredential']){ $spCommand.Remove('SqlCredential') }

                    # Get the devices that have the package
                    $Query = "USE CM_$($SyncClass.SyncHash.ConfigMgrSC); SELECT SP.ResourceID,CS.Name00,CS.Domain00,SP.ContentID,SP.Version FROM SuperPeerContentMap as SP `
                        INNER JOIN SMSPackages_All as PL on SP.ContentID = PL.PkgID `
                        INNER JOIN Computer_System_DATA as CS on CS.MachineID = SP.ResourceID `
                        WHERE SP.ContentID = '$($SyncClass.SyncHash.SelectedItem.ContentID)' `
                        ORDER BY CS.Name00"
                    $Packages = @()
                    $Packages += (Connect-DbaInstance @spCommand).Query($Query)

                    # Add devices to the list that have the package
                    foreach($p in $Packages)
                    {
                        $obj = [PSCustomObject]@{            
                            ResourceID = $p.ResourceID
                            Name = $p.Name00
                            Domain = $p.Domain00
                            ContentID = $p.ContentID
                            Version = $p.Version
                        }
                        $SyncClass.SyncHash.DataGridList.add($obj)
                    }
                }

                #Clear the filter
                $SyncClass.UpdateElement("formMainWindowControlDataGridFilter","Text","")
            }
            catch
            {
                [System.Windows.Messagebox]::Show("There was an error getting info from the database. Does the account have the appropriate read permissions to the ConfigMgr Database?","ERROR In DB Query")
            }

            # Give the user access again
            $SyncClass.UpdateElement("formMainWindowControlLoadingOverlay","Visibility","Collapsed")
            $SyncClass.UpdateElement("formMainWindowControlRefreshButton","IsEnabled",$true)
        }
    }
})

# If there are selected items, enable the buttons
$formMainWindowControlContentDataGrid.Add_SelectionChanged({
    if($formMainWindowControlContentDataGrid.SelectedItems)
    {
        #$formMainWindowControlValidateContent.IsEnabled = $true
        $formMainWindowControlRemoveContent.IsEnabled = $true
    }
    else
    {
        #$formMainWindowControlValidateContent.IsEnabled = $false
        $formMainWindowControlRemoveContent.IsEnabled = $false
    }
})

<#
$formMainWindowControlValidateContent.Add_Click({
    
    foreach($si in $formMainWindowControlContentDataGrid.SelectedItems)
    {
        $gwmi = Get-WmiObject -ComputerName "$($s.Name)" -Namespace "root\ccm\SoftMgmtAgent" -Query "select * from CacheInfoEx where ContentId = '$($si.ContentID)' and ContentVer = '$($si.Version)'"
        Write-Host $gwmi.Location
        $computer = "$($si.Name).$($si.Domain)"
        Invoke-POWmi -ScriptBlock {Get-FileHash C:\Windows} -ComputerName $computer -BypassCreds
    }
})
#>

# What hapens when you click to remove content?? All this fun
$formMainWindowControlRemoveContent.Add_Click({
    $SyncClass.SyncHash.GridSelectedItems = @()
    foreach($si in $formMainWindowControlContentDataGrid.SelectedItems)
    {
        $SyncClass.SyncHash.GridSelectedItems += [pscustomobject]@{
            ContentId = $si.ContentId;
            Version = $si.Version;
            Name = $si.Name;
            Domain = $si.Domain;
        }
    }
    
    $formMainWindowControlLoadingText.Content = "Removing Selected Content"
    $formMainWindowControlLoadingOverlay.Visibility = "Visible"
    $formMainWindowControlRefreshButton.IsEnabled = $false

    # Do it in the background :D
    Start-BackgroundScriptBlock -scriptBlock {
        Import-Module "$($SyncClass.SyncHash.ScriptRoot)\Scripts\POWmi\POWmi.psm1"
        foreach($si in $SyncClass.SyncHash.GridSelectedItems)
        {
            # Create a script to run over WMI
            $sb = [ScriptBlock]::Create("
                `$rmObj = New-Object -ComObject 'UIResource.UIResourceMgr'
                `$cacheObject = `$rmObj.GetCacheInfo()
                `$cacheItem = `$cacheObject.GetCacheElements() | Where-Object -Property ContentId -EQ -Value `"$($si.ContentId)`" | Where-Object -Property ContentVersion -EQ -Value `"$($si.Version)`"
                `$cacheObject.DeleteCacheElementEx(`$cacheItem.CacheElementId,`$true)
            ")
            $computer = "$($si.Name).$($si.Domain)"

            # Execute the script over WMI
            $null = Invoke-POWmi -ComputerName $computer -ScriptBlock $sb -BypassCreds -ErrorAction SilentlyContinue
        }
        $SyncClass.UpdateElement("formMainWindowControlLoadingOverlay","Visibility","Collapsed")
        $SyncClass.UpdateElement("formMainWindowControlRefreshButton","IsEnabled",$true)
    }

    # Remove all selected items from list (hacky, but it works)
    while($formMainWindowControlContentDataGrid.SelectedItems)
    {
        $formMainWindowControlContentDataGrid.ItemsSource.Remove($formMainWindowControlContentDataGrid.SelectedItems[0])
    }
})