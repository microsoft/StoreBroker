# Copyright (C) Microsoft Corporation.  All rights reserved.

@{
    GUID = '10d324f0-4333-4ef7-9e85-93b7fc83f5fb'
    Author = 'Microsoft Corporation'
    CompanyName = 'Microsoft Corporation'
    Copyright = 'Copyright (C) Microsoft Corporation.  All rights reserved.'

    ModuleVersion = '1.12.0'
    Description = 'Provides command-line access to the Windows Store Submission REST API.'

    RootModule = 'StoreIngestionApi'

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        'Helpers.ps1',
        'NugetTools.ps1',
        'PackageTool.ps1',
        'StoreIngestionApplicationApi.ps1',
        'StoreIngestionIapApi.ps1',
        'StoreIngestionFlightingApi.ps1',
        'Telemetry.ps1')

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '4.0'

    FunctionsToExport = @(
        'Clear-StoreBrokerAuthentication',
        'Complete-ApplicationFlightSubmission',
        'Complete-ApplicationFlightSubmissionPackageRollout',
        'Complete-ApplicationSubmission',
        'Complete-ApplicationSubmissionPackageRollout',
        'Complete-InAppProductSubmission',
        'Format-Application',
        'Format-ApplicationFlight',
        'Format-ApplicationFlightSubmission',
        'Format-ApplicationFlights',
        'Format-ApplicationInAppProducts',
        'Format-ApplicationSubmission',
        'Format-Applications',
        'Format-InAppProduct',
        'Format-InAppProductSubmission',
        'Format-InAppProducts',
        'Get-Application',
        'Get-ApplicationFlight',
        'Get-ApplicationFlightSubmission',
        'Get-ApplicationFlightSubmissionPackageRollout',
        'Get-ApplicationFlightSubmissionStatus',
        'Get-ApplicationFlights',
        'Get-ApplicationInAppProducts',
        'Get-ApplicationSubmission',
        'Get-ApplicationSubmissionPackageRollout',
        'Get-ApplicationSubmissionStatus',
        'Get-Applications',
        'Get-FlightGroups',
        'Get-InAppProduct',
        'Get-InAppProductSubmission',
        'Get-InAppProductSubmissionStatus',
        'Get-InAppProducts',
        'Get-SubmissionPackage',
        'Invoke-SBRestMethod',
        'Invoke-SBRestMethodMultipleResult',
        'Join-SubmissionPackage',
        'New-ApplicationFlight',
        'New-ApplicationFlightSubmission',
        'New-ApplicationSubmission',
        'New-InAppProductSubmission',
        'New-InAppProductSubmissionPackage',
        'New-InAppProduct',
        'New-StoreBrokerConfigFile',
        'New-StoreBrokerInAppProductConfigFile',
        'New-SubmissionPackage',
        'Open-DevPortal',
        'Open-Store',
        'Remove-ApplicationFlight',
        'Remove-ApplicationFlightSubmission',
        'Remove-ApplicationSubmission',
        'Remove-InAppProduct',
        'Remove-InAppProductSubmission',
        'Set-ApplicationFlightSubmission',
        'Set-ApplicationSubmission',
        'Set-InAppProductSubmission',
        'Set-StoreBrokerAuthentication',
        'Set-SubmissionPackage',
        'Start-ApplicationFlightSubmissionMonitor',
        'Start-InAppProductSubmissionMonitor',
        'Start-SubmissionMonitor',
        'Stop-ApplicationFlightSubmissionPackageRollout',
        'Stop-ApplicationSubmissionPackageRollout',
        'Update-ApplicationFlightSubmission',
        'Update-ApplicationFlightSubmissionPackageRollout',
        'Update-ApplicationSubmission',
        'Update-ApplicationSubmissionPackageRollout',
        'Update-InAppProductSubmission')

    AliasesToExport = @(
        'Commit-ApplicationFlightSubmission',
        'Commit-ApplicationSubmission',
        'Commit-IapSubmission',
        'Commit-InAppProductSubmission',
        'Complete-InAppProductSubmission',
        'Finalize-ApplicationFlightSubmissionPackageRollout',
        'Finalize-ApplicationSubmissionPackageRollout',
        'Format-ApplicationIaps',
        'Format-Iap',
        'Format-IapSubmission',
        'Format-Iaps',
        'Get-ApplicationIaps',
        'Get-Iap',
        'Get-IapSubmission',
        'Get-IapSubmissionStatus',
        'Get-Iaps',
        'Halt-ApplicationFlightSubmissionPackageRollout',
        'Halt-ApplicationSubmissionPackageRollout',
        'New-Iap',
        'New-IapSubmission',
        'New-IapSubmissionPackage',
        'New-PackageToolConfigFile',
        'New-StoreBrokerIapConfigFile',
        'Remove-Iap',
        'Remove-IapSubmission',
        'Replace-ApplicationFlightSubmission',
        'Replace-ApplicationSubmission',
        'Replace-IapSubmission',
        'Replace-InAppProductSubmission',
        'Set-IapSubmission',
        'Set-SubmissionPackage',
        'Start-ApplicationSubmissionMonitor',
        'Start-IapSubmissionMonitor',
        'Update-IapSubmission',
        'Upload-ApplicationSubmissionPackage',
        'Upload-SubmissionPackage')

    #CmdletsToExport = '*'

    #VariablesToExport = '*'

    # Private data to pass to the module specified in RootModule/ModuleToProcess. 
    PrivateData = @{
        # Hashtable with additional module metadata used by PowerShell.
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Store', 'App', 'Submission')

            # A URL to the license for this module.
            LicenseUri = 'https://aka.ms/StoreBroker_License'

            # A URL to the main website for this project.
            ProjectUri = 'https://aka.ms/StoreBroker'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''
        }
    }

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = 'SB'

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # HelpInfo URI of this module
    # HelpInfoURI = ''
}
