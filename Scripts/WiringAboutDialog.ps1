# Create a custom dialog window and add it to the main window
$AboutDialog = [MahApps.Metro.Controls.Dialogs.CustomDialog]::new($formMainWindow)
$AboutDialog.AddChild($formAboutDialog)

# Show the dialog when about is pressed
$formMainWindowControlAboutButton.Add_Click({
    $settings             = [MahApps.Metro.Controls.Dialogs.MetroDialogSettings]::new()
    $settings.ColorScheme = [MahApps.Metro.Controls.Dialogs.MetroDialogColorScheme]::Theme 
    [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMetroDialogAsync($formMainWindow, $AboutDialog, $settings)
})

# Close the dialog when ok button pressed
$formAboutDialogControlAboutOKButton.Add_Click({
    $AboutDialog.RequestCloseAsync() 
})