$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'dc'
            Role = 'dc'
            MachineName = 'DC'
            DomainName = 'contoso.com'
            IPAddress = '192.168.29.254'
            InterfaceAlias = 'Ethernet'
            DefaultGateway = '192.168.29.254'
            SubnetMask = '24'
            AddressFamily = 'IPv4'
            DNSAddress = '127.0.0.1', '8.8.8.8'
            PSDscAllowPlainTextPassword = $true
        }
        @{
            NodeName = 'dfs1'
            Role = 'dfs'
            MachineName = 'dfs1'
            DomainName = 'contoso.com'
            IPAddress = '192.168.29.2'
            InterfaceAlias = 'Ethernet0'
            DefaultGateway = '192.168.29.254'
            SubnetMask = '24'
            AddressFamily = 'IPv4'
            DNSAddress = '192.168.29.254','8.8.8.8'
            PSDscAllowPlainTextPassword = $true
         }
        @{
            NodeName = 'dfs2'
            Role = 'dfs'
            MachineName = 'dfs2'
            DomainName = 'contoso.com'
            IPAddress = '192.168.29.3'
            InterfaceAlias = 'Ethernet0'
            DefaultGateway = '192.168.29.254'
            SubnetMask = '24'
            AddressFamily = 'IPv4'
            DNSAddress = '192.168.29.254','8.8.8.8'
            PSDscAllowPlainTextPassword = $true
          }
    )
}

Configuration DSC1 {
    param (
        [Parameter(Mandatory)]
        [pscredential]$safemodeCred,
        [Parameter(Mandatory)]
        [pscredential]$domainCred,
        [pscredential]$Credential
    )
    Import-DscResource -Module xActiveDirectory, xComputerManagement, xNetworking, xDhcpServer
    Node $AllNodes.Where{$_.Role -eq 'dc'}.NodeName {
        xIPAddress SetIP {
            IPAddress = $Node.IPAddress
            InterfaceAlias = $Node.InterfaceAlias
            DefaultGateway = $Node.DefaultGateway
            SubnetMask = $Node.SubnetMask
            AddressFamily = $Node.AddressFamily
        }
        WindowsFeature ADDSInstall {
            Ensure = 'Present'
            Name = 'RemoteAccess'
        }
        xDNSServerAddress SetDNS {
            Address = $Node.DNSAddress
            InterfaceAlias = $Node.InterfaceAlias
            AddressFamily = $Node.AddressFamily
        }
        WindowsFeature ADDSInstall {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
        }
        WindowsFeature ADDSToolsInstall {
            Ensure = 'Present'
            Name = 'RSAT-AD-Tools'
        }
        xADDomain FirstDC {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $domainCred
            SafemodeAdministratorPassword = $safemodeCred
            DependsOn = '[xIPAddress]SetIP', '[WindowsFeature]ADDSInstall'
        }
    
        WindowsFeature DHCPInstall {
            Ensure = 'Present'
            Name = 'Dhcp'
        }
        xDhcpServerScope CreateScope 
        { 
             Ensure = 'Present' 
             IPEndRange = '192.168.29.250' 
             IPStartRange = '192.168.29.10' 
             Name = 'PowerShellScope' 
             SubnetMask = '255.255.255.0' 
             LeaseDuration = '00:08:00' 
             State = 'Active' 
             AddressFamily = 'IPv4' 
        } 
        xDhcpServerOption Option
        {
            Ensure = 'Present'
            ScopeID = '192.168.29.0' 
            DnsDomain = 'contoso.com' 
            DnsServerIPAddress = '192.168.29.254','8.8.8.8' 
            AddressFamily = 'IPv4' 
        }
    }
    Node $AllNodes.Where{$_.Role -eq 'dfs'}.NodeName {
        xIPAddress SetIP {
            IPAddress = $Node.IPAddress
            InterfaceAlias = $Node.InterfaceAlias
            DefaultGateway = $Node.DefaultGateway
            SubnetMask = $Node.SubnetMask
            AddressFamily = $Node.AddressFamily
        }
    }
}

DSC1 -OutputPath c:\DSC\Roles\Config â€“ConfigurationData $ConfigData -Credential (Get-Credential)
#Set-DscLocalConfigurationManager -Path C:\DSC\Roles\Config -Credential (Get-Credential) -Verbose
#Test-DscConfiguration -CimSession dc 
Start-DscConfiguration -ComputerName dc -Wait -Path C:\DSC\Roles\Config -Credential (Get-Credential) -Verbose -Force
$session = New-PSSession -ComputerName 192.168.29.5,192.168.29.6 -Credential (Get-Credential)
Invoke-Command -Session $session {Find-Module xActiveDirectory, xComputerManagement, xNetworking, xDhcpServer | Install-Module}
Start-DscConfiguration -ComputerName 192.168.29.5 -Wait -Path C:\DSC\Roles\Config -Credential (Get-Credential) -Verbose -Force