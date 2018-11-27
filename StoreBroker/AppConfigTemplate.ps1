[ordered]@{
    "helpUri" = "https:\\\\aka.ms\\StoreBroker_Config";
    "schemaVersion" = 2;
    "packageParameters" = [ordered]@{
                              "PDPRootPath" = "";
                              "Release" = "";
                              "PDPInclude" = @();
                              "PDPExclude" = @();
                              "LanguageExclude" = @(
                                                      "default"
                                                  );
                              "MediaRootPath" = "";
                              "MediaFallbackLanguage" = "";
                              "PackagePath" = @();
                              "OutPath" = "";
                              "OutName" = "";
                              "DisableAutoPackageNameFormatting" = $false
                          };
    "appSubmission" = [ordered]@{
                          "productId" = "";
                          "targetPublishMode" = "NotSet";
                          "targetPublishDate" = $null;
                          "visibility" = "NotSet";
                          "pricing" = [ordered]@{
                                          "priceId" = "NotAvailable";
                                          "trialPeriod" = "NoFreeTrial";
                                          "marketSpecificPricings" = [ordered]@{};
                                          "sales" = @()
                                      };
                          "allowTargetFutureDeviceFamilies" = [ordered]@{
                                                                  "Xbox" = $false;
                                                                  "Team" = $false;
                                                                  "Holographic" = $false;
                                                                  "Desktop" = $false;
                                                                  "Mobile" = $false
                                                              };
                          "allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies" = $false;
                          "enterpriseLicensing" = "None";
                          "applicationCategory" = "NotSet";
                          "hardwarePreferences" = @();
                          "hasExternalInAppProducts" = $false;
                          "meetAccessibilityGuidelines" = $false;
                          "canInstallOnRemovableMedia" = $false;
                          "automaticBackupEnabled" = $false;
                          "isGameDvrEnabled" = $false;
                          "gamingOptions" = @(
                                                [ordered]@{
                                                    "genres" = @();
                                                    "isLocalMultiplayer" = $false;
                                                    "isLocalCooperative" = $false;
                                                    "isOnlineMultiplayer" = $false;
                                                    "isOnlineCooperative" = $false;
                                                    "localMultiplayerMinPlayers" = 0;
                                                    "localMultiplayerMaxPlayers" = 0;
                                                    "localCooperativeMinPlayers" = 0;
                                                    "localCooperativeMaxPlayers" = 0;
                                                    "isBroadcastingPrivilegeGranted" = $false;
                                                    "isCrossPlayEnabled" = $false;
                                                    "kinectDataForExternal" = "Disabled"
                                                }
                                            );
                          "notesForCertification" = ""
                      }
}