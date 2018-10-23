# Copyright (C) Microsoft Corporation.  All rights reserved.

@{
    GUID = '10d324f0-4333-4ef7-9e85-93b7fc83f5fb'
    Author = 'Microsoft Corporation'
    CompanyName = 'Microsoft Corporation'
    Copyright = 'Copyright (C) Microsoft Corporation.  All rights reserved.'

    ModuleVersion = '2.0.0'
    Description = 'Provides command-line access to the Windows Store Submission REST API.'

    RootModule = 'StoreIngestionApi'

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        'ConvertFrom-ExistingSubmission.ps1',
        'Helpers.ps1',
        'NugetTools.ps1',
        'PackageTool.ps1',

        'StoreIngestionFeatureAvailabilityApi.ps1',
        'StoreIngestionFeatureGroupApi.ps1',
        'StoreIngestionGroupApi.ps1',
        'StoreIngestionFlightApi.ps1',
        'StoreIngestionListingApi.ps1',
        'StoreIngestionListingImageApi.ps1',
        'StoreIngestionListingVideoApi.ps1',
        'StoreIngestionPackageApi.ps1',
        'StoreIngestionPackageConfigurationApi.ps1',
        'StoreIngestionProductApi.ps1',
        'StoreIngestionProductAvailabilityApi.ps1',
        'StoreIngestionPropertyApi.ps1',
        'StoreIngestionRolloutApi.ps1',
        'StoreIngestionSubmissionApi.ps1',


        'Telemetry.ps1')

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '4.0'

    FunctionsToExport = @(
        'New-FeatureAvailability',
        'Set-FeatureAvailability',
        'Get-FeatureAvailability',

        'Remove-FeatureGroup',
        'New-FeatureGroup',
        'Set-FeatureGroup',
        'Get-FeatureGroup',

        'Get-Group',
        'New-Group',
        'Set-Group',

        'New-Flight',
        'Remove-Flight',
        'Get-Flight',
        'Set-Flight',
        'Update-Flight',

        'New-Listing',
        'Remove-Listing',
        'Get-Listing',
        'Set-Listing',
        'Update-Listing',

        'New-ListingImage',
        'Remove-ListingImage',
        'Get-ListingImage',
        'Set-ListingImage',
        'Update-ListingImage',

        'New-ListingVideo',
        'Remove-ListingVideo',
        'Get-ListingVideo',
        'Set-ListingVideo',
        'Update-ListingVideo',

        'Get-Product',
        'New-Product',
        'Remove-Product',
        'Get-ProductPackageIdentity',
        'Get-ProductRelated',
        'Get-ProductStoreLink',

        'Get-Submission',
        'Get-SubmissionDetail',
        'Set-SubmissionDetail',
        'Update-SubmissionDetail',
        'Get-SubmissionReport',
        'Get-SubmissionValidation',
        'Remove-Submission',
        'New-Submission',
        'Stop-Submission',
        'Submit-Submission',
        'Publish-Submission',
        'Push-Submission',
        'Update-Submission',

        'Get-SubmissionRollout',
        'Set-SubmissionRollout',
        'Update-SubmissionRollout',

        'Remove-ProductPackage',
        'Get-ProductPackage',
        'New-ProductPackage',
        'Set-ProductPackage',
        'Update-ProductPackage',
        'Wait-ProductPackageProcessed',

        'Get-ProductPackageConfiguration',
        'New-ProductPackageConfiguration',
        'Set-ProductPackageConfiguration',
        'Update-ProductPackageConfiguration',

        'Get-ProductProperty',
        'New-ProductProperty',
        'Set-ProductProperty',
        'Update-ProductProperty',

        'Get-ProductAvailability',
        'New-ProductAvailability',
        'Set-ProductAvailability',
        'Update-ProductAvailability',

        'ConvertFrom-ExistingSubmission',

        'Clear-StoreBrokerAuthentication',
        'Get-StoreFile',
        'Invoke-SBRestMethod',
        'Invoke-SBRestMethodMultipleResult',
        'Join-SubmissionPackage',
        'New-StoreBrokerConfigFile',
        'New-StoreBrokerInAppProductConfigFile',
        'New-SubmissionPackage',
        'Open-DevPortal',
        'Open-Store',
        'Set-StoreBrokerAuthentication',
        'Set-StoreFile',
        'Start-ApplicationFlightSubmissionMonitor',
        'Start-InAppProductSubmissionMonitor',
        'Start-SubmissionMonitor')

    AliasesToExport = @(
        'Delete-Product',
        'Delete-Submission',
        'Cancel-Submission',
        'Commit-Submission',
        'Complete-Submission',
        'Promote-Submission',
        'Delete-ProductPackage',
        'Delete-Listing',
        'Delete-ListingImage',
        'Delete-ListingVideo',
        'Delete-Flight',
        'Delete-FeatureGroup',
        'New-SubmissionDetail',


        'Get-SubmissionPackage',
        'New-PackageToolConfigFile',
        'New-StoreBrokerIapConfigFile',
        'Set-SubmissionPackage',
        'Start-ApplicationSubmissionMonitor',
        'Start-IapSubmissionMonitor',
        'Upload-ApplicationSubmissionPackage',
        'Upload-StoreFile',
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
