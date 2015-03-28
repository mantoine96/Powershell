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
    }
}

DSC1 -OutputPath c:\DSC\Roles\Config –ConfigurationData $ConfigData -Credential (Get-Credential)
Set-DscLocalConfigurationManager -Path C:\DSC\Roles\Config -Credential (Get-Credential) -Verbose
Test-DscConfiguration -CimSession dc 
Start-DscConfiguration -Wait -Path C:\DSC\Roles\Config -Credential (Get-Credential) -Verbose -Force