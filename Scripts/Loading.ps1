# The general refresh script
$RefreshSB = {
    # Disable refresh button and show loading overlay
    $formMainWindowControlLoadingOverlay.Visibility = "Visible"
    $formMainWindowControlRefreshButton.IsEnabled = $false

    # Disable the content buttons (validate comes later)
    #$formMainWindowControlValidateContent.IsEnabled = $false
    $formMainWindowControlRemoveContent.IsEnabled = $false
    
    # Don't Act on Selection Changed (see WiringMainWindow.ps1)
    $SyncClass.SyncHash.ActOnAny = $false
    $SyncClass.SyncHash.DataGridList.Clear() # Clear anything in the datagrid already

    # Initialize Variables
    # SuperPeer List
    $formMainWindowControlLoadingText.Content = "Initializing Variables..."
    $SyncClass.SyncHash.SuperPeerList = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
    $SyncClass.SyncHash.SuperPeerListLock = New-Object PSObject
    $SyncClass.SyncHash.SuperPeerView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($SyncClass.SyncHash.SuperPeerList)
    $formMainWindowControlSuperPeerListBox.DisplayMemberPath = 'Name00'
    $formMainWindowControlSuperPeerListBox.ItemsSource = $SyncClass.SyncHash.SuperPeerView

    # Create a binding to pair the listbox to the observable collection
    $SuperPeerListBinding = New-Object System.Windows.Data.Binding
    $SuperPeerListBinding.Source = $SyncClass.SyncHash.SuperPeerList
    $SuperPeerListBinding.Mode = [System.Windows.Data.BindingMode]::OneWay
    [void][System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($SyncClass.SyncHash.SuperPeerList,$SyncClass.SyncHash.SuperPeerListLock)
    [void][System.Windows.Data.BindingOperations]::SetBinding($formMainWindowControlSuperPeerListBox,[System.Windows.Controls.ListBox]::ItemsSourceProperty, $SuperPeerListBinding)

    # Package/Application List
    $SyncClass.SyncHash.AppPkgList = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
    $SyncClass.SyncHash.AppPkgListLock = New-Object PSObject
    $SyncClass.SyncHash.AppPkgView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($SyncClass.SyncHash.AppPkgList)
    $formMainWindowControlPackageListBox.DisplayMemberPath = 'Name'
    $formMainWindowControlPackageListBox.ItemsSource = $SyncClass.SyncHash.AppPkgView

    # Create a binding to pair the listbox to the observable collection
    $AppPkgListBinding = New-Object System.Windows.Data.Binding
    $AppPkgListBinding.Source = $SyncClass.SyncHash.AppPkgList
    $AppPkgListBinding.Mode = [System.Windows.Data.BindingMode]::OneWay
    [void][System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($SyncClass.SyncHash.AppPkgList,$SyncClass.SyncHash.AppPkgListLock)
    [void][System.Windows.Data.BindingOperations]::SetBinding($formMainWindowControlPackageListBox,[System.Windows.Controls.ListBox]::ItemsSourceProperty, $AppPkgListBinding)

    # Start running the following tasks in the background
    # as they may take a bit of time to run
    Start-BackgroundScriptBlock -scriptBlock {
        if(!$SyncClass.SyncHash.DBAToolsInstalled)
        {
            $SyncClass.UpdateElement("formMainWindowControlLoadingText","Content","Checking for DBATools...")
            # Install DBATools if it doesn't exist
            if(!(Get-Module -ListAvailable -Name dbatools))
            {
                $SyncClass.UpdateElement("formMainWindowControlLoadingText","Content","Installing DBATools for $ENV:Username...")
                if(!(Get-PackageProvider -Name NuGet -ListAvailable))
                {
                    [System.Windows.MessageBox]::Show("DBATools is not installed, and requires NuGet Package Manager to automatically install for the user. Please run the following command from an elevated command prompt:`n`nInstall-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force","ERROR!!",0,48)
                    $SyncClass.CloseWindow("formMainWindow")
                }
                Install-Module dbatools -Scope CurrentUser -Force
            }
            Import-Module dbatools
            $SyncClass.SyncHash.DBAToolsInstalled = $true
        }

        # Begin Automatic Loading of Content IF Server is set
        if(![string]::IsNullOrEmpty($SyncClass.SyncHash.ConfigMgrDS))
        {
            $SyncClass.UpdateElement("formMainWindowControlLoadingText","Content","Loading SuperPeers")
            try{
                $spCommand = @{ 
                    'SqlInstance' = $SyncClass.SyncHash.ConfigMgrDS 
                    'Database' = "CM_$($SyncClass.SyncHash.ConfigMgrSC)"
                }
                if($SyncClass.SyncHash.AlternateCredentials){$spCommand['SqlCredential'] = $SyncClass.SyncHash.AlternateCredentials}
                elseif($spCommand['SqlCredential']){ $spCommand.Remove('SqlCredential') }
                
                # Query to get all machines that are super peers
                $Query = "USE CM_$($SyncClass.SyncHash.ConfigMgrSC); SELECT SP.ResourceID,CS.Domain00,CS.Name00 FROM SuperPeers as SP `
                         INNER JOIN Computer_System_DATA as CS on CS.MachineID = SP.ResourceID `
                         ORDER BY CS.Name00"
                
                $SuperPeers = (Connect-DbaInstance @spCommand).Query($Query)
                
                # Add SuperPeers to the observable collection
                foreach($sp in $SuperPeers)
                {
                    $obj = [PSCustomObject]@{
                        Name00 = $sp.Name00
                        Domain00 = $sp.Domain00
                        ResourceID = $sp.ResourceID
                    }
                    $SyncClass.SyncHash.SuperPeerList.add($obj)
                }

                $SyncClass.UpdateElement("formMainWindowControlLoadingText","Content","Loading Packages")
                $spCommand = @{ 
                    'SqlInstance' = $SyncClass.SyncHash.ConfigMgrDS 
                    'Database' = "CM_$($SyncClass.SyncHash.ConfigMgrSC)"
                }
                if($SyncClass.SyncHash.AlternateCredentials){$spCommand['SqlCredential'] = $SyncClass.SyncHash.AlternateCredentials}
                elseif($spCommand['SqlCredential']){ $spCommand.Remove('SqlCredential') }
                
                # Query all packages
                $Query = "USE CM_$($SyncClass.SyncHash.ConfigMgrSC); SELECT DISTINCT SP.ContentID,PL.Name FROM SuperPeerContentMap as SP `
                          INNER JOIN SMSPackages_All as PL on SP.ContentID = PL.PkgID `
                          ORDER BY PL.Name"
                $Packages = @()
                $Packages += (Connect-DbaInstance @spCommand).Query($Query)
            

                $SyncClass.UpdateElement("formMainWindowControlLoadingText","Content","Loading Applications")
                $spCommand = @{ 
                    'SqlInstance' = $SyncClass.SyncHash.ConfigMgrDS 
                    'Database' = "CM_$($SyncClass.SyncHash.ConfigMgrSC)"
                }
                if($SyncClass.SyncHash.AlternateCredentials){$spCommand['SqlCredential'] = $SyncClass.SyncHash.AlternateCredentials}
                elseif($spCommand['SqlCredential']){ $spCommand.Remove('SqlCredential') }
                
                # Query all applications
                $Query = "USE CM_$($SyncClass.SyncHash.ConfigMgrSC); SELECT DISTINCT SP.ContentID,LAC.DisplayName as Name FROM SuperPeerContentMap as SP `
                          INNER JOIN vSMS_CIToContent as CI on SP.ContentID = CI.Content_UniqueID `
                          INNER JOIN fn_ListDeploymentTypeCIs(1033) as LCI on LCI.CI_ID = CI.CI_ID `
                          INNER JOIN fn_ListApplicationCIs(1033) as LAC on LAC.ModelName = LCI.AppModelName `
                          ORDER BY LAC.DisplayName"
                $Apps = @()
                $Apps += (Connect-DbaInstance @spCommand).Query($Query)

                # Add apps to observable collection
                foreach($p in $Apps)
                {
                    $obj = [PSCustomObject]@{
                        ContentID = $p.ContentID
                        Name = "APP - $($p.Name)"
                    }
                    $SyncClass.SyncHash.AppPkgList.add($obj)
                }

                # Add packages to observable collection
                foreach($p in $Packages)
                {
                    $obj = [PSCustomObject]@{
                        ContentID = $p.ContentID
                        Name = "PKG - $($p.Name)"
                    }
                    $SyncClass.SyncHash.AppPkgList.add($obj)
                }
            }
            catch
            {
                # Something went wrong - probably bad credentials
                [System.Windows.Messagebox]::Show("There was an error getting info from the database. Does the account have the appropriate read permissions to the ConfigMgr Database?","ERROR In DB Query")
            }
        }
        $SyncClass.UpdateElement("formMainWindowControlLoadingOverlay","Visibility","Collapsed")
        $SyncClass.UpdateElement("formMainWindowControlRefreshButton","IsEnabled",$true)
        
        # Allow selection changes to refresh the datagrid
        $SyncClass.SyncHash.ActOnAny = $true
    }
}

# Run when the window is displayed
$formMainWindow.Add_ContentRendered({
    Invoke-Command -ScriptBlock $RefreshSB
})

# Run when the refresh button is pressed
$formMainWindowControlRefreshButton.Add_Click({
    Invoke-Command -ScriptBlock $RefreshSB
})