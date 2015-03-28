$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'dc'
            MachineName = 'DC'
            DomainName = 'contoso.com'
            IPAddress = '192.168.29.254'
            InterfaceAlias = 'Ethernet'
            DefaultGateway = '192.168.29.254'
            SubnetMask = '24'
            AddressFamily = 'IPv4'
            DNSAddress = '127.0.0.1', '192.168.29.254'
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
    Node $AllNodes.NodeName {
        xIPAddress SetIP {
            IPAddress = $Node.IPAddress
            InterfaceAlias = $Node.InterfaceAlias
            DefaultGateway = $Node.DefaultGateway
            SubnetMask = $Node.SubnetMask
            AddressFamily = $Node.AddressFamily
            Users = Import-Csv C:\users.csv
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
        xADDomain FirstDC {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $domainCred
            SafemodeAdministratorPassword = $safemodeCred
            DependsOn = '[xIPAddress]SetIP', '[WindowsFeature]ADDSInstall'
        }

        xADUser AddingUsers {
            Ensure = 'Present'
            DomainName = 'contoso.com'
            DomainAdministratorCredential = $domainCred
            UserName = 
            DependsOn = '[WindowsFeature]ADDSInstall' ,'[xADDomain]FirstDC'

        }
    
        WindowsFeature DHCPInstall {
            Ensure = 'Present'
            Name = 'Dhcp'
        }
        xDhcpServerScope CreateScope 
        { 
             Ensure = 'Present' 
             IPEndRange = '192.168.29.250' 
             IPStartRange = '192.168.29.5' 
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
}

DSC1 -OutputPath c:\DSC\Roles\Config –ConfigurationData $ConfigData -Credential (Get-Credential)
Set-DscLocalConfigurationManager -Path C:\DSC\Roles\Config -Credential (Get-Credential) -Verbose
Test-DscConfiguration -CimSession dc 
Start-DscConfiguration -Wait -Path C:\DSC\Roles\Config -Credential (Get-Credential) -Verbose -Force
