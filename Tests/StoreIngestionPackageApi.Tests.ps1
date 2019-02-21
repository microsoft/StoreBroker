# Need to split-path $MyInvocation.MyCommand.Path twice and then add StoreBroker folder
$sbModulePath = Join-Path ($MyInvocation.MyCommand.Path | Split-Path -Parent | Split-Path -Parent) "StoreBroker"

Import-Module $sbModulePath

InModuleScope StoreBroker {
    Describe "StoreIngestionPackageApi" {

        Context "Get-PackagesToKeep" {
            It "returns empty when there is no package" {
                $packages = @()
                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 1 | Should BeNullOrEmpty
            }

            It "keeps all packages because there is only one bundle package" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-8832-73904c3183c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 1 | Should BeExactly $expectedOutput
            }

            It "keeps the highest version of x86 bundle packages" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X86'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-a832-73904c2383c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 1 | Should BeExactly $expectedOutput
            }

            It "keeps all the x86 and x64 bundles because the number of packages to keep is 2" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-a832-73904c2383c8', '2c4024fa-2b22-4019-8832-73904c3183c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 2 | Should BeExactly $expectedOutput
            }

            It "keeps the 2 highest versions of x86 bundle packages" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X86'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20201.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20201.0'; 'architecture'='X86'}
                        )
                        'version' = '16040.10827.20201.0'
                        'id' = '2cbbbbfa-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-a832-73904c2383c8', '2cbbbbfa-2b22-4019-a832-73904c2383c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 2 | Should BeExactly $expectedOutput
            }

            It "keeps the latest version of x86 and x64 bundle packages" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-a832-73904c2383c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 1 | Should BeExactly $expectedOutput
            }

            It "keeps the latest 2 versions of x86 and x64 bundle packages" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20201.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20201.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20201.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2cbbbbfa-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-a832-73904c2383c8', '2cbbbbfa-2b22-4019-a832-73904c2383c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 2 | Should BeExactly $expectedOutput
            }

            It "keeps bundles because there are 3 x86 bundles, 2 x64 bundles, the package with largest x86 bundle does not have x64 bundle, and the number of packages to keep is 2" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20201.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20201.0'; 'architecture'='X86'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2cbbbbfa-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-8832-73904c3183c8', '2c4024fa-2b22-4019-a832-73904c2383c8', '2cbbbbfa-2b22-4019-a832-73904c2383c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 2 | Should BeExactly $expectedOutput
            }

            It "keeps bundles because there are 3 x86 bundles, 2 x64 bundles, and the package with second largest version does not reference x64 bundle, and the number of packages to keep is 2" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X86'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20201.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20201.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20201.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2cbbbbfa-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-8832-73904c3183c8', '2c4024fa-2b22-4019-a832-73904c2383c8', '2cbbbbfa-2b22-4019-a832-73904c2383c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 2 | Should BeExactly $expectedOutput
            }

            It "keeps all bundle packages because one of them still references x86 and the higher version doesn't" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-a832-73904c2383c8', '2c4024fa-2b22-4019-8832-73904c3183c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 1 | Should BeExactly $expectedOutput
            }

            It "keeps both bundle packages because one targets Windows Desktop and Mobile, and the higher version just targets Desktop" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                            @{'name'='Windows.Mobile'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-a832-73904c2383c8', '2c4024fa-2b22-4019-8832-73904c3183c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 1 | Should BeExactly $expectedOutput
            }

            It "keeps 2 packages that have the higher bundle versions for Desktop" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                            @{'name'='Windows.Mobile'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20201.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20201.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c40bbbb-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-a832-73904c2383c8', '2c40bbbb-2b22-4019-a832-73904c2383c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 2 | Should BeExactly $expectedOutput
            }

            It "keeps all packages because one only has Desktop bundle, another only has Mobile bundle, and the other one has both, and the number of packages to keep is 2" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Mobile'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20191.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c4024fa-2b22-4019-a832-73904c2383c8'
                    },
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                            @{'name'='Windows.Mobile'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20191.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20201.0'; 'architecture'='X86'},
                            @{'contentType'='Application';'version'='16040.10827.20201.0'; 'architecture'='X64'}
                        )
                        'version' = '16040.10827.20131.0'
                        'id' = '2c40bbbb-2b22-4019-a832-73904c2383c8'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-8832-73904c3183c8', '2c4024fa-2b22-4019-a832-73904c2383c8', '2c40bbbb-2b22-4019-a832-73904c2383c8')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 2 | Should BeExactly $expectedOutput
            }

            It "keeps all packages(bundle and non-bundle) because the target platforms for each package is different" {
                $packages = @(
                    @{          
                        'architecture' = 'Neutral'
                        'targetPlatforms' = @(
                            @{'name'='Windows.Desktop'; 'minVersion'='10.0.17134.0'; 'maxVersionTested'='10.0.17649.0'}
                        )
                        'bundleContents' = @(
                            @{'contentType'='Resource';'version'='16040.10827.20181.0'; 'architecture'='Neutral'},
                            @{'contentType'='Application';'version'='16040.10827.20181.0'; 'architecture'='X86'}
                        )
                        'version' = '16040.10827.20181.0'
                        'id' = '2c4024fa-2b22-4019-8832-73904c3183c8'
                    },
                    @{          
                        'architecture' = 'Arm'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3025'
                        'id' = 'pcs-ws-1152921505688159433-905546'
                    }
                )

                $expectedOutput = @('2c4024fa-2b22-4019-8832-73904c3183c8', 'pcs-ws-1152921505688159433-905546')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 1 | Should BeExactly $expectedOutput
            }

            It "keeps 1 non-bundle package because the architectures and target platforms for both packages are the same" {
                $packages = @(
                    @{          
                        'architecture' = 'Arm'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3023'
                        'id' = 'pcs-ws-115292150asd88159433-905546'
                    },
                    @{          
                        'architecture' = 'Arm'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3025'
                        'id' = 'pcs-ws-1152921505688159433-905546'
                    }
                )

                $expectedOutput = @('pcs-ws-1152921505688159433-905546')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 1 | Should BeExactly $expectedOutput
            }

            It "keeps 2 non-bundle package because the architectures and target platforms for both packages are the same" {
                $packages = @(
                    @{          
                        'architecture' = 'Arm'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3023'
                        'id' = 'pcs-ws-115292150asd88159433-905546'
                    },
                    @{          
                        'architecture' = 'Arm'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3025'
                        'id' = 'pcs-ws-1152921505688159433-905546'
                    }
                    @{          
                        'architecture' = 'Arm'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3026'
                        'id' = 'pcs-ws-bbbb921505688159433-905546'
                    }
                )

                $expectedOutput = @('pcs-ws-bbbb921505688159433-905546', 'pcs-ws-1152921505688159433-905546')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 2 | Should BeExactly $expectedOutput
            }

            It "keeps both non-bundle packages because they have different architecture" {
                $packages = @(
                    @{          
                        'architecture' = 'X64'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3023'
                        'id' = 'pcs-ws-115292150asd88159433-905546'
                    },
                    @{          
                        'architecture' = 'Arm'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3023'
                        'id' = 'pcs-ws-1152921505688159433-905546'
                    }
                )

                $expectedOutput = @('pcs-ws-1152921505688159433-905546', 'pcs-ws-115292150asd88159433-905546')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 1 | Should BeExactly $expectedOutput
            }

            It "keeps all non-bundle packages because they have different architecture" {
                $packages = @(
                    @{          
                        'architecture' = 'X64'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3023'
                        'id' = 'pcs-ws-115292150asd88159433-905546'
                    },
                    @{          
                        'architecture' = 'Arm'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3023'
                        'id' = 'pcs-ws-1152921505688159433-905546'
                    },
                    @{          
                        'architecture' = 'X86'
                        'targetPlatforms' = @(
                            @{'name'='Windows80'}
                        )
                        'bundleContents' = @()
                        'version' = '16.0.1601.3023'
                        'id' = 'pcs-ws-bbbb921505688159433-905546'
                    }
                )

                $expectedOutput = @('pcs-ws-1152921505688159433-905546', 'pcs-ws-115292150asd88159433-905546', 'pcs-ws-bbbb921505688159433-905546')

                Get-PackagesToKeep -Package $packages -RedundantPackagesToKeep 2 | Should BeExactly $expectedOutput
            }
        }
    }
}
