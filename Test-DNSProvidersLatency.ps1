#Requires -Modules ImportExcel
<#
    .SYNOPSIS
        Tests DNS providers latency, outputs results to the terminal.
    
    .NOTES
        Author: Olav Rønnestad Birkeland
        Created:  200601
        Modified: 200601

    .EXAMPLE
        # Run from PowerShell ISE        
        & $psISE.'CurrentFile'.'FullPath'
        & $psISE.'CurrentFile'.'FullPath' -DnsTypes 'All'
        & $psISE.'CurrentFile'.'FullPath' -DnsTypes 'Custom' -CustomDnsProviders '1.1.1.1'
        & $psISE.'CurrentFile'.'FullPath' -DnsTypes 'Regular'
        & $psISE.'CurrentFile'.'FullPath' -DnsTypes 'Security'
        & $psISE.'CurrentFile'.'FullPath' -DnsTypes 'Security' -OutputToExcel
        & $psISE.'CurrentFile'.'FullPath' -DnsTypes 'All' -CustomDnsProviders '1.1.1.1'
        & $psISE.'CurrentFile'.'FullPath' -DnsTypes 'SystemConfigured' -CustomDnsProviders '1.1.1.1'
        & $psISE.'CurrentFile'.'FullPath' -DnsTypes 'Security','SystemConfigured' -CustomDnsProviders '1.1.1.1'
#>



# Input
[OutputType($null)]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Adult','All','Custom','Family','Non-filtered','Regular','Security','SystemConfigured')]
    [string[]] $DnsTypes = 'All',

    [Parameter(Mandatory = $false)]
    [string[]] $Domains,

    [Parameter(Mandatory = $false)]
    [string[]] $CustomDnsProviders,

    [Parameter(Mandatory = $false)]
    [byte] $Average = 5,

    [Parameter(Mandatory = $false)]
    [byte] $Decimals = 4,

    [Parameter(Mandatory = $false)]
    [switch] $OutputToExcel
)




# Preferences
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'



# Failproof
## Internet connection
if (-not [bool]$($null = Resolve-DnsName -Name 'google.com' -ErrorAction 'SilentlyContinue';$?)) {
    Throw 'ERROR: Make sure you are connected to the internet, did not manage to resolve "google.com".'
}

## Custom DNS
if ($CustomDnsProviders.ForEach{Try{$null=[System.Version]$_;$?}Catch{$false}} -contains $false) {
    Throw 'ERROR: Wrong format on provided custom DNS providers. Must be a IPv4 address.'
}

## Excel
if ($OutputToExcel) {
    if ($(Import-Module -Name 'ImportExcel' -ErrorAction 'SilentlyContinue').'Count' -le 0) {
        $null = Import-Module -Name 'ImportExcel' -ErrorAction 'SilentlyContinue'
        if (-not $?) {
            Throw 'ERROR: PowerShell module "ImportExcel" from PowerShellGallery must be installed if using the "OutputToExcel" switch.'
        }
    }
}




######################################################
#region Try / Catch
Try {
######################################################



# Assets
## Domains
if (-not $Domains) {
    $Domains = [string[]](
        'finn.no',
        'forum.xdadevelopers.com',
        'google.com',
        'vg.no',
        'youtube.com'
    )
}

## DNS Providers
### DnsTypes
#### Initialize variable
$DnsTypesFixed = [string[]]($DnsTypes)
#### Remove other
if ($DnsTypes -contains 'All') {
    $DnsTypesFixed = [string[]]('All')
}
### DNS Providers
#### Initialize variable
$DnsProviders = [PSCustomObject[]]$()
#### Custom DNS providers
if ($CustomDnsProviders.'Count' -gt 0) {
    # Add to DnsTypes
    if ($DnsTypesFixed -notcontains 'Custom') {
        $DnsTypesFixed += [string[]]('Custom')
    }
    # Add to $DnsProviders
    $DnsProviders += [PSCustomObject[]](
        [PSCustomObject]@{
            'Name'    = 'Custom'
            'About'   = ''
            'Servers' = [PSCustomObject[]]$(
                $CustomDnsProviders | ForEach-Object -Process {
                    [PSCustomObject]@{
                        'Type' = 'Custom{0}' -f (1+$CustomDnsProviders.IndexOf($_))
                        'IPv4' = [System.Version] $_
                    }
                }
            )
        }
    )
}
#### Add list of providers
if (
    # Three or more DNS types specified
    $DnsTypesFixed.'Count' -gt 2 -or 
    # Two DNS types specified
    ($DnsTypesFixed.'Count' -eq 2 -and $($DnsTypes.ForEach{$_ -in 'SystemConfigured','Custom'}) -notcontains $false) -or
    # One DNS type specified
    $DnsTypesFixed[0] -notin 'SystemConfigured','Custom'
) {
    $DnsProviders += [PSCustomObject[]](
        # AdGuard
        [PSCustomObject]@{
            'Name'    = 'AdGuard'
            'About'   = 'https://adguard.com/en/adguard-dns/overview.html'
            'Servers' = [PSCustomObject[]](
                [PSCustomObject]@{
                    'Type' = 'Family'
                    'IPv4' = [System.Version] '176.103.130.132'
                },
                [PSCustomObject]@{
                    'Type' = 'Non-filtered'
                    'IPv4' = [System.Version] '176.103.130.136'
                },
                [PSCustomObject]@{
                    'Type' = 'Regular'
                    'IPv4' = [System.Version] '176.103.130.130'
                }
            )
        },
        # CleanBrowsing
        [PSCustomObject]@{
            'Name'   = 'CleanBrowsing'
            'About'  = 'https://cleanbrowsing.org/'
            'Servers' = [PSCustomObject[]](
                [PSCustomObject]@{
                    'Type' = 'Adult'
                    'IPv4' = [System.Version] '185.228.168.10'
                },
                [PSCustomObject]@{
                    'Type' = 'Family'
                    'IPv4' = [System.Version] '185.228.168.168'
                },
                [PSCustomObject]@{
                    'Type' = 'Security'
                    'IPv4' = [System.Version] '185.228.168.9'
                }
            )
        },
        # Cloudflare
        [PSCustomObject]@{
            'Name'   = 'Cloudflare'
            'About'  = 'https://1.1.1.1/'
            'Servers' = [PSCustomObject[]](
                [PSCustomObject]@{
                    'Type' = 'Adult'
                    'IPv4' = [System.Version] '1.1.1.3'
                },
                [PSCustomObject]@{
                    'Type' = 'Regular'
                    'IPv4' = [System.Version] '1.1.1.1'
                },
                [PSCustomObject]@{
                    'Type' = 'Security'
                    'IPv4' = [System.Version] '1.1.1.2'
                }
            )
        },
        # Comodo
        [PSCustomObject]@{
            'Name'   = 'Comodo'
            'About'  = 'https://www.comodo.com/secure-dns/'
            'Servers' = [PSCustomObject[]](
                [PSCustomObject]@{
                    'Type' = 'Regular'
                    'IPv4' = [System.Version] '8.26.56.26'
                }
            )
        },
        # Google
        [PSCustomObject]@{
            'Name'   = 'Google'
            'About'  = 'https://developers.google.com/speed/public-dns/docs/using'
            'Servers' = [PSCustomObject[]](
                [PSCustomObject]@{
                    'Type' = 'Regular'
                    'IPv4' = [System.Version] '8.8.8.8'
                }
            )
        },
        # OpenDNS
        [PSCustomObject]@{
            'Name'   = 'OpenDNS'
            'About'  = 'https://www.opendns.com/'
            'Servers' = [PSCustomObject[]](
                [PSCustomObject]@{
                    'Type' = 'Family'
                    'IPv4' = [System.Version] '208.67.222.123'
                },
                [PSCustomObject]@{
                    'Type' = 'Regular'
                    'IPv4' = [System.Version] '208.67.222.222'
                }
            )
        },
        # Neustar
        [PSCustomObject]@{
            'Name'   = 'Neustar'
            'About'  = 'https://www.publicdns.neustar/'
            'Servers' = [PSCustomObject[]](
                [PSCustomObject]@{
                    'Type' = 'Family'
                    'IPv4' = [System.Version] '156.154.70.3'
                },
                [PSCustomObject]@{
                    'Type' = 'Regular'
                    'IPv4' = [System.Version] '156.154.70.5'
                },
                [PSCustomObject]@{
                    'Type' = 'Security'
                    'IPv4' = [System.Version] '156.154.70.2'
                }
            )
        },
        # Quad9
        [PSCustomObject]@{
            'Name'   = 'Quad9'
            'About'  = 'https://www.quad9.net/'
            'Servers' = [PSCustomObject[]](
                [PSCustomObject]@{
                    'Type' = 'Security'
                    'IPv4' = [System.Version] '9.9.9.9'
                }
            )
        },
        # Yandex
        [PSCustomObject]@{
            'Name'   = 'Yandex'
            'About'  = 'https://dns.yandex.com/'
            'Servers' = [PSCustomObject[]](
                [PSCustomObject]@{
                    'Type' = 'Family'
                    'IPv4' = [System.Version] '77.88.8.7'
                },
                [PSCustomObject]@{
                    'Type' = 'Regular'
                    'IPv4' = [System.Version] '77.88.8.8'
                },
                [PSCustomObject]@{
                    'Type' = 'Security'
                    'IPv4' = [System.Version] '77.88.8.88'
                }
            )
        }
    )
}
#### Add system configured DNS servers
if ($DnsTypesFixed.ForEach{$_ -in 'All','SystemConfigured'} -contains $false) {
    # Get system configured DNS servers
    $SystemConfigured = [System.Version[]]([string[]]($(Get-DnsClientServerAddress).'ServerAddresses'.Where{Try{$null=[System.Version]$($_);$true}catch{$false}} | Sort-Object -Unique))

    # Add if any where found
    if ($SystemConfigured.'Count' -gt 0) {
        $DnsProviders += [PSCustomObject[]](
            [PSCustomObject]@{
                'Name'    = 'SystemConfigured'
                'About'   = 'https://docs.microsoft.com/en-us/powershell/module/dnsclient/get-dnsclientserveraddress?view=win10-ps'
                'Servers' = [PSCustomObject[]]$(
                    $SystemConfigured.ForEach{
                        [PSCustomObject]@{
                            'Type' = 'SystemConfigured{0}' -f (1+$SystemConfigured.IndexOf($_))
                            'IPv4' = $_
                        }
                    }
                )
            }
        )
    }
}
#### Filter according to $DnsType
$DnsProviders = [PSCustomObject[]]$(
    if ($DnsTypesFixed -contains 'All') {
        $DnsProviders
    }
    else {
        # Filter out servers
        $DnsProviders.ForEach{            
            $_.'Servers' = [PSCustomObject[]](
                $_.'Servers'.Where{                
                    $x = $_
                    $DnsTypesFixed.ForEach{
                        $x.'Type' -match $_
                    } -contains $true                
                }
            )
        }
        # Return result        
        Write-Output -InputObject $DnsProviders.Where{
            $_.'Servers'.'Count' -gt 0
        }
    }
)
#### Sort
$DnsProviders = [PSCustomObject[]]($DnsProviders | Sort-Object -Property 'Name')
$DnsProviders.ForEach{$_.'Servers' = $_.'Servers' | Sort-Object -Property 'Type'}



# Test
## Information
Write-Information -MessageData '# Testing'
Write-Information -MessageData (
    '{0} domain{1} {2} time{3} per DNS provider.' -f (
        $Domains.'Count'.ToString(),
        $(if($Domains.'Count' -ne 1){'s'}),
        $Average.ToString(),
        $(if($Average -ne 1){'s'})
    )
)

## Create array for test servers
$DnsServers = [PSCustomObject[]]$(
    foreach ($DnsProvider in $DnsProviders) {
        $DnsProvider.'Servers' | ForEach-Object -Process {
            [PSCustomObject]@{
                'Name' = '{0} - {1}' -f $DnsProvider.'Name',$_.'Type'
                'IPv4' = $_.'IPv4'
            }
        }
    }
)

## Do the testing
### Formatting
$OutputUnit = [string] 'ms'
$Formatting = [string]('0.{0}{1}' -f (('0'*$Decimals),$OutputUnit))
### Initialize $Results variable
$Results = [PSCustomObject[]]$()
### Test
foreach ($DnsServer in $DnsServers) {
    # Information
    Write-Information -MessageData (
        '{0} / {1} "{2}" {3}' -f (
            (1+$DnsServers.IndexOf($DnsServer)).ToString('0'*$DnsServers.'Count'.ToString().'Length'),
            $DnsServers.'Count'.ToString(),
            $DnsServer.'Name',
            $DnsServer.'IPv4'
        )
    )

    foreach ($Domain in $Domains) {
        # Test
        $Result = [PSCustomObject]@{
            'DNSProviderName' = $DnsServer.'Name'
            'DNSProviderIPv4' = $DnsServer.'IPv4'
            'Domain'          = $Domain
            'Tests'           = [decimal[]](
                $(
                    # Re-use previous test results if same IPv4 already have been tested
                    $PreviousTest = $Results.Where{$_.'DNSProviderIPv4' -eq $DnsServer.'IPv4' -and $_.'Domain' -eq $Domain}
                    if ($PreviousTest) {
                        $PreviousTest.'Tests'
                    }
                    # Else, test
                    else {                        
                        1 .. $Average | ForEach-Object -Process {
                            $(
                                Measure-Command -Expression {
                                    Resolve-DnsName -Name $Domain -Server $DnsServer.'IPv4' -Type 'A' -NoHostsFile
                                }
                            ).'TotalMilliseconds'.ToString()
                        }
                    }
                )
            )
        }

        # Add average
        $null = Add-Member -InputObject $Result -MemberType 'NoteProperty' -Name 'Average' -Value ($([decimal]$($Result.'Tests' | Measure-Object -Sum).'Sum'/$Average).ToString($Formatting))

        # Add tests as table view, makes it easier for output later
        foreach ($Index in [byte[]](0 .. ($Average - 1))) {
            $null = Add-Member -InputObject $Result -MemberType 'NoteProperty' -Name ('Test{0}' -f ($Index+1)) -Value ($Result.'Tests'[$Index].ToString($Formatting))
        }

        # Add $Result to $Results
        $Results += [PSCustomObject[]]($Result)
    }
}




# View results
## Information
Write-Information -MessageData ('{0}# View results' -f ([System.Environment]::NewLine))

## Prepare
### Excel
if ($OutputToExcel) {
    $Path = [string](
        '{0}\DnsProvidersTest-{1}-{2}.xlsx' -f (
            [System.Environment]::GetFolderPath('Desktop'),
            $DnsType,
            [datetime]::Now.ToString('yyyyMMdd-HHmmss')
        )
    )
    $TableStyle = [string] 'Medium2'
}

## Average per domain per DNS provider
### Information
Write-Information -MessageData 'Average per domain per DNS provider'
### Create table view
$OutTableView = [array]($Results | Sort-Object -Property 'Domain',@{'Expression'={[decimal]$_.'Average'.Replace($OutputUnit,'')}} | Select-Object -Property '*' -ExcludeProperty 'Tests')
### View in console
$OutTableView | Format-Table -AutoSize
### Output to Excel
if ($OutputToExcel) {
    $Title = 'AllResults'
    $OutTableView | Export-Excel -Path $Path -TableStyle $TableStyle -WorksheetName $Title -AutoSize -Title $Title
}

## Average per DNS provider
### Information
Write-Information -MessageData 'Average per DNS provider for all domains'
### Create table view
$OutTableView = [array](
    $([array]($Results | Group-Object -Property 'DNSProviderName' | Sort-Object -Property 'Name')).ForEach{
        $SumAverage = [PSCustomObject]($_.'Group'.'Tests' | Measure-Object -Sum | Select-Object -Property 'Count','Sum')
        [PSCustomObject]@{
            'DNSProviderName' = $_.'Group'[0].'DNSProviderName'
            'DNSProviderIPv4' = $_.'Group'[0].'DNSProviderIPv4'
            'Average'         = [string] ($SumAverage.'Sum' / $SumAverage.'Count').ToString($Formatting)
        }
    } | Sort-Object -Property @{'Expression'={[decimal]$_.'Average'.Replace($OutputUnit,'')}}
)
### View in console
$OutTableView | Format-Table -AutoSize
### Output to Excel
if ($OutputToExcel) {
    $Title = 'ProvidersAverage'
    $OutTableView | Export-Excel -Path $Path -TableStyle $TableStyle -WorksheetName $Title -AutoSize -Title $Title
}

## Average per domain
### Information
Write-Information -MessageData 'Average per domain'
### Create table view
$OutTableView = [array](
    $Results | Group-Object -Property 'Domain' | ForEach-Object -Process {
        $SumAverage = [PSCustomObject]($_.'Group'.'Tests' | Measure-Object -Sum | Select-Object -Property 'Count','Sum')
        [PSCustomObject]@{
            'Domain'  = $_.'Name'
            'Average' = [string] ($SumAverage.'Sum' / $SumAverage.'Count').ToString($Formatting)
        }
    } | Sort-Object -Property @{'Expression'={[decimal]$_.'Average'.Replace($OutputUnit,'')}}
)
### View in console
$OutTableView | Format-Table -AutoSize
### Output to Excel
if ($OutputToExcel) {
    $Title = 'DomainsAverage'
    $OutTableView | Export-Excel -Path $Path -TableStyle $TableStyle -WorksheetName $Title -AutoSize -Title $Title
}



######################################################
#endregion Try / Catch
}
Catch {
    # Construct error message
    ## Generic content
    $ErrorMessage = [string]$('{0}Catched error:' -f ([System.Environment]::NewLine))    
    ## Last exit code if any
    if (-not[string]::IsNullOrEmpty($LASTEXITCODE)) {
        $ErrorMessage += ('{0}# Last exit code ($LASTEXITCODE):{0}{1}' -f ([System.Environment]::NewLine,$LASTEXITCODE))
    }
    ## Exception
    $ErrorMessage += [string]$('{0}# Exception:{0}{1}' -f ([System.Environment]::NewLine,$_.'Exception'))
    ## Dynamically add info to the error message
    foreach ($ParentProperty in [string[]]$($_.GetType().GetProperties().'Name')) {
        if ($_.$ParentProperty) {
            $ErrorMessage += ('{0}# {1}:' -f ([System.Environment]::NewLine,$ParentProperty))
            foreach ($ChildProperty in [string[]]$($_.$ParentProperty.GetType().GetProperties().'Name')) {
                ### Build ErrorValue
                $ErrorValue = [string]::Empty
                if ($_.$ParentProperty.$ChildProperty -is [System.Collections.IDictionary]) {
                    foreach ($Name in [string[]]$($_.$ParentProperty.$ChildProperty.GetEnumerator().'Name')) {
                        if (-not[string]::IsNullOrEmpty([string]$($_.$ParentProperty.$ChildProperty.$Name))) {
                            $ErrorValue += ('{0} = {1}{2}' -f ($Name,[string]$($_.$ParentProperty.$ChildProperty.$Name),[System.Environment]::NewLine))
                        }
                    }
                }
                else {
                    $ErrorValue = [string]$($_.$ParentProperty.$ChildProperty)
                }
                if (-not[string]::IsNullOrEmpty($ErrorValue)) {
                    $ErrorMessage += ('{0}## {1}\{2}:{0}{3}' -f ([System.Environment]::NewLine,$ParentProperty,$ChildProperty,$ErrorValue.Trim()))
                }
            }
        }
    }
    # Write Error Message
    Write-Error -Message $ErrorMessage -ErrorAction 'Continue'
}
######################################################
