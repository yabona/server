Add-PSSnapin Microsoft.SharePoint.PowerShell -ea 0;  
    $ErrorActionPreference = "SilentlyContinue";  

    $PropertyMap=@("Title,PreferredName,Display Name",  
    "EMail,WorkEmail,EMail",  
    "MobilePhone,CellPhone,Mobile Phone",  
    "Notes,AboutMe,About Me",  
    "SipAddress,WorkEmail,Sip Address",  
    "Picture,PictureURL,Picture URL",  
    "Department,Department,Department",  
    "JobTitle,SPS-JobTitle,Job Title",  
    "FirstName,FirstName,First Name",  
    "LastName,LastName,Last Name",  
    "WorkPhone,WorkPhone,Work Phone",  
    "UserName,UserName,UserName",  
    "WebSite,WebSite,WebSite",  
    "SPSResponsibility,SPS-Responsibility,Ask About Me",  
    "Office,Office,Office");  

    $Context = Get-SPServiceContext $(Get-SPWebApplication -IncludeCentralAdministration | ? {$_.IsAdministrationWebApplication}).Url;  
    $ProfileManager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileManager($Context);  

    if($ProfileManager){  
        foreach ($Site in $(Get-SPSite -Limit All | ? {!$_.Url.Contains("Office_Viewing_Service_Cache")})){  
            $RootWeb = $Site.RootWeb;  
            Write-Host $($Site.Url);  

            foreach ($User in $($RootWeb.SiteUsers)){  
                if ($ProfileManager.UserExists($($User.UserLogin))){  
                    $UPUser = $ProfileManager.GetUserProfile($($User.UserLogin));  
                    $UserList = $RootWeb.SiteUserInfoList;  

                    $Query = New-Object Microsoft.SharePoint.SPQuery;  
                    $Query.Query = "<Where><Eq><FieldRef Name='Name' /><Value Type='Text'>$($User.UserLogin)</Value></Eq></Where>";  
                    $UserItem = $UserList.GetItems($Query)[0];  

                    ForEach ($Map in $PropertyMap){  
                        $PropName = $Map.Split(',')[0];  
                        $SiteProp = $UserItem[$PropName];  
                        $UPSProp = $UPUser[$($Map.Split(',')[1])].Value;  
                        $DisplayName = $Map.Split(',')[2];  

                        if($PropName -eq "Notes"){  
                            #Write-Host "$DisplayName Updated: $SiteProp - $($UPSProp[0].Replace("&nbsp;"," "))";  
                            $UserItem[$PropName] = $($UPSProp[0].Replace("&nbsp;"," "));  
                        }elseif($PropName -eq "Picture"){  
                            #Write-Host "$DisplayName Updated: $($SiteProp.Split(",")[0]) - $($UPSProp[0])";  
                            $UserItem[$PropName] = $UPSProp[0];  
                        }elseif($PropName -eq "SPSResponsibility"){  
                            #Write-Host "$DisplayName Updated: $SiteProp - $($UPSProp -join ', ')";  
                            $UserItem[$PropName] = $($UPSProp -join ', ');  
                        }else{  
                            #Write-Host "$DisplayName Updated: $SiteProp - $UPSProp";  
                            $UserItem[$PropName] = $UPSProp;  
                        }  
                    }  
                    #Write-Host "Saving: $($User.UserLogin)";  
                    $UserItem.SystemUpdate();  
                    #Write-Host "";  
                }  
            }  
            $RootWeb.Dispose();  
            #Write-Host "";  
        }   
    }else{  
        Write-Host -foreground red "Cant connect to the User Profile Service. Please make sure that the UPS is connected to the Central Administration Web Application. Also make sure that you have Administrator Rights to the User Profile Service";  
    } 