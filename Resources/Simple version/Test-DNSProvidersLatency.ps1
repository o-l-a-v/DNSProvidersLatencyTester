<#
    .SYNOPSIS
        Tests DNS providers latency, outputs results to the terminal.
    
    .NOTES
        Author: Olav Rønnestad Birkeland
        Created:  200531
        Modified: 200601
#>


# Assets
## Preferences
$InformationPreference = 'Continue'

## Settings
$Average               = [byte] 5
$Decimals              = [byte] 4
$ShowXResultsInOutput  = [byte] 8

## Domains
$Domains = [string[]](
    'finn.no',
    'forum.xdadevelopers.com',
    'google.com',
    'vg.no',
    'youtube.com'
)

## DNS Providers
$DnsProviders = [ordered]@{
    # AdGuard - https://adguard.com/en/adguard-dns/overview.html
    'AdGuard - Family'         = [System.Version] '176.103.130.132'
    'AdGuard - Non-filtered'   = [System.Version] '176.103.130.136'
    'AdGuard - Regular'        = [System.Version] '176.103.130.130'
    # Cleanbrowsing - https://cleanbrowsing.org/
    'CleanBrowsing - Adult'    = [System.Version] '185.228.168.10'
    'CleanBrowsing - Family'   = [System.Version] '185.228.168.168'
    'CleanBrowsing - Security' = [System.Version] '185.228.168.9'    
    # Cloudflare - https://1.1.1.1/
    'Cloudflare - Regular'     = [System.Version] '1.1.1.1'
    'Cloudflare - Malware'     = [System.Version] '1.1.1.2'
    'Cloudflare - Child'       = [System.Version] '1.1.1.3'
    # Comodo - https://www.comodo.com/secure-dns/
    'Comodo'                   = [System.Version] '8.26.56.26'
    # Google - https://developers.google.com/speed/public-dns/docs/using
    'Google'                   = [System.Version] '8.8.8.8'
    # OpenDNS - https://www.opendns.com/
    'OpenDNS - Regular'        = [System.Version] '208.67.222.222'
    'OpenDNS - Family'         = [System.Version] '208.67.222.123'       
    # Neustar - https://www.publicdns.neustar/
    'Neustar - Family'         = [System.Version] '156.154.70.3'
    'Neustar - Regular'        = [System.Version] '156.154.70.5'
    'Neustar - Security'       = [System.Version] '156.154.70.2'
    # Quad9 - https://www.quad9.net/
    'Quad9'                    = [System.Version] '9.9.9.9'
    # Yandex - https://dns.yandex.com/
    'Yandex - Basic'           = [System.Version] '77.88.8.8'
    'Yandex - Family'          = [System.Version] '77.88.8.7'
    'Yandex - Safe'            = [System.Version] '77.88.8.88'
}
$DnsProviderNames = [array]($DnsProviders.GetEnumerator().'Name' | Sort-Object)



# Test
## Information
Write-Information -MessageData '# Testing'
Write-Information -MessageData (
    '{0} domain{1} {2} time{3} per DNS provider.' -f (
        $Domains.'Count'.ToString(),
        $(if($Domains.'Count' -ne 1){'s'}),
        $Average.ToString(),
        $(if($Average.'Count' -ne 1){'s'})
    )
)

## Test
$Results = [PSCustomObject[]]$(
    foreach ($DnsProviderName in $DnsProviderNames) {
        # Information
        Write-Information -MessageData (
            '{0} / {1} "{2}" {3}' -f (
                (1+$DnsProviderNames.IndexOf($DnsProviderName)).ToString('0'*$DnsProviderNames.'Count'.ToString().'Length'),
                $DnsProviderNames.'Count'.ToString(),
                $DnsProviderName,
                $DNSProviders.$DnsProviderName.ToString()                
            )
        )

        foreach ($Domain in $Domains) {                        
            # Test
            $Result = [PSCustomObject]@{
                'DNSProviderName' = $DnsProviderName
                'DNSProviderIPv4' = $DnsProviders.$DnsProviderName
                'Domain'          = $Domain
                'Tests'           = [decimal[]](
                    0 .. $Average | ForEach-Object -Process {
                        $(
                            Measure-Command -Expression {
                                Resolve-DnsName -Name $Domain -Server $DnsProviders.$DnsProviderName -Type 'A' -NoHostsFile
                            }
                        ).'TotalMilliseconds'
                    }
                )
            }

            # Add average
            $null = Add-Member -InputObject $Result -MemberType 'NoteProperty' -Name 'Average' -Value ([decimal]$($Result.'Tests' | Measure-Object -Sum).'Sum'/$Average)

            # Return the result
            Write-Output -InputObject $Result
        }
    }
)



# View results
## Information
Write-Information -MessageData ('{0}# View results' -f ([System.Environment]::NewLine))

## Formatting
$OutputUnit = [string] 'ms'
$Formatting = [string]('0.{0}{1}' -f (('0'*$Decimals),$OutputUnit))

## Average per domain per DNS provider
Write-Information -MessageData 'Average per domain per DNS provider'
$Properties = [array](
    'DNSProviderName',
    'DNSProviderIPv4',
    'Domain',
    @{
        'Name'       = 'Average'
        'Expression' = {
            [string] $_.'Average'.ToString($Formatting)
        }
    } +
    $(
        foreach ($Index in [byte[]](0 .. $(if($Decimals -le $ShowXResultsInOutput){$Decimals}else{$ShowXResultsInOutput}))) {        
            @{
                'Name'       = 'Test{0}' -f $Index
                'Expression' = {
                    [string] $_.'Tests'[$Index].ToString($Formatting)
                }
            }
        }
    )
)
$Results | Sort-Object -Property 'Domain','Average' | Select-Object -Property $Properties | Format-Table -AutoSize

## Average per DNS provider
Write-Information -MessageData 'Average per DNS provider for all domains'
$([array]($Results | Group-Object -Property 'DNSProviderIPv4')).ForEach{
    $SumAverage = [PSCustomObject]($_.'Group'.'Tests' | Measure-Object -Sum | Select-Object -Property 'Count','Sum')
    [PSCustomObject]@{
        'DNSProviderName' = $_.'Group'[0].'DNSProviderName'
        'DNSProviderIPv4' = $_.'Group'[0].'DNSProviderIPv4'
        'Average'         = [string] ($SumAverage.'Sum' / $SumAverage.'Count').ToString($Formatting)
    }
} | Sort-Object -Property @{'Expression'={[decimal] $_.'Average'.Replace($OutputUnit,'')}} | Format-Table -AutoSize
