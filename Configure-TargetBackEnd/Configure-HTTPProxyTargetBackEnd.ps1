<#
	.SYNOPSIS
    Configure client-specific message size limits.
       
   	Michel de Rooij
	michel@eightwone.com
	http://eightwone.com
	
	THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
	RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
	Version 1.1, February 4th, 2016

	.DESCRIPTION
	Configure maximum concurrent Target Backend request for proxying RPC, OWA and EAS requests.
    Prevents 2002 messages (and Connection_Dropped_Event_List_Full in Httperr)

    .PARAMETER Server
    Specifies server to configure. When omitted, will configure local server.

    .PARAMETER AllServers
    Process all Exchange Client Access servers

    .PARAMETER TargetBackEnd
    Specifies Target Backend limit (default 150).

	.LINK
	http://eightwone.com

	Revision History
	---------------------------------------------------------------------
	1.0		Initial release
	1.1		Added OWA

#>
#Requires -Version 3.0

[cmdletbinding(SupportsShouldProcess = $true, DefaultParameterSetName= 'Local')]
param(
	[parameter( Mandatory=$false, ParameterSetName = 'Server')]
		[string]$Server= $env:ComputerName,
    [parameter( Mandatory=$false, ParameterSetName = 'All')]
    [parameter( Mandatory=$false, ParameterSetName = 'Server')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$TargetBackEnd=150,
    [parameter( Mandatory=$true, ParameterSetName = 'All')]
        [switch]$AllServers
)

process {

    $ERR_NOEMS                      = 1001
    $ERR_NOT2013SERVER              = 1002
    $ERR_CANTACCESSWEBCONFIG		= 1004
    $ERR_RUNNINGNONADMINMODE        = 1010

    function Get-WCFFileName( $ExInstallPath, $FileName) {
        $WebConfigFile= Join-Path $ExInstallPath $FileName
        $WebConfigFile= Join-Path "\\$Identity\" ( Join-Path ($WebConfigFile.subString(0,1) + '$') $WebConfigFile.subString(2))
        If( -not (Test-Path $WebConfigFile)) {
            Write-Error "Can't determine or access $WebConfigFile"
            Exit $ERR_CANTACCESSWEBCONFIG
        }
        return $WebConfigFile
    }

    function update-XMLNode( $XML, $Path, $Key, $Value) {
        $Parent= $xml.SelectSingleNode( $Path)
        $Node = $XML.SelectSingleNode("$Path/add[@key=""$Key""]")
        if ($Node) {
            $temp = $Parent.RemoveChild( $Node)
        }
        $root = $xml.get_DocumentElement();         
        $Node = $xml.CreateNode('element',"add","")    
        $Node.SetAttribute("key", $Key)
        $Node.SetAttribute("value", $Value)
        $temp =  $xml.SelectSingleNode( $Path).AppendChild( $Node)
        Return $XML
    }

	Function is-Admin {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )
        return ( $currentPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator ))
    }
   
    # MAIN
    Try {
        $tmp= Get-ExchangeServer -ErrorAction SilentlyContinue
    }
    Catch {
        Write-Error "Exchange Management Shell not loaded"
        Exit $ERR_NOEMS
    }

    If( $AllServers) {

        If(! ( is-Admin)) {
            Write-Error "Script requires running in elevated mode"
            Exit $ERR_RUNNINGNONADMINMODE
        }
        $ServerList= Get-ExchangeServer | Where { ($_.AdminDisplayVersion).Major -eq 15 } | Sort-Object -Property { $_.Fqdn -eq (Get-PSSession).ComputerName }
    }
    Else {
        If( (Get-ExchangeServer -Identity $Server).adminDisplayVersion.Major -ne 15) {
            Write-Error "$Server appears not to be an Exchange 2013/2016 server"
            Exit $ERR_NOT2013SERVER
        }
        $ServerList= @( $Server)
    }

    ForEach( $Identity in $ServerList) {

        $ThisServer= Get-ExchangeServer -Identity $Identity
        $Version= $ThisServer.AdminDisplayVersion.Major
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Identity)
        $ExInstallPath = $reg.OpenSubKey("SOFTWARE\Microsoft\ExchangeServer\v$Version\Setup").GetValue("MsiInstallPath")

        if( $TargetBackEnd) {
            If( $ThisServer.isClientAccessServer) {
                $wcfFile= Get-WCFFileName $ExInstallPath "FrontEnd\HttpProxy\sync\web.config"
                $wcfXML= [xml](Get-Content $wcfFile)
                Write-Output "Processing $wcfFile"
                $wcfXML= Update-XMLNode $wcfXML '//configuration/appSettings' 'HttpProxy.ConcurrencyGuards.TargetBackendLimit' $TargetBackEnd
                Copy-Item $wcfFile ($wcfFile + "_"+ ( Get-Date).toString("yyyMMddHHmmss")+ ".bak") -Force
                $wcfXML.Save( $wcfFile)
                $wcfFile= Get-WCFFileName $ExInstallPath "FrontEnd\HttpProxy\rpc\web.config"
                $wcfXML= [xml](Get-Content $wcfFile)
                Write-Output "Processing $wcfFile"
                $wcfXML= Update-XMLNode $wcfXML '//configuration/appSettings' 'HttpProxy.ConcurrencyGuards.TargetBackendLimit' $TargetBackEnd
                Copy-Item $wcfFile ($wcfFile + "_"+ ( Get-Date).toString("yyyMMddHHmmss")+ ".bak") -Force
                $wcfXML.Save( $wcfFile)
                $wcfFile= Get-WCFFileName $ExInstallPath "FrontEnd\HttpProxy\owa\web.config"
                $wcfXML= [xml](Get-Content $wcfFile)
                Write-Output "Processing $wcfFile"
                $wcfXML= Update-XMLNode $wcfXML '//configuration/appSettings' 'HttpProxy.ConcurrencyGuards.TargetBackendLimit' $TargetBackEnd
                Copy-Item $wcfFile ($wcfFile + "_"+ ( Get-Date).toString("yyyMMddHHmmss")+ ".bak") -Force
                $wcfXML.Save( $wcfFile)
            }

            Write-Output "Restarting MSExchangeOWAAppPool on $Identity"
            $AppPool= Get-WMIObject -ComputerName $Identity -Namespace "root\MicrosoftIISv2" -Class "IIsApplicationPool" -Authentication PacketPrivacy | Where { $_.Name -eq "W3SVC/APPPOOLS/MSExchangeOwaAppPool"}
            $AppPool.Recycle()
            Write-Output "Restarting MSExchangeSyncAppPool on $Identity"
            $AppPool= Get-WMIObject -ComputerName $Identity -Namespace "root\MicrosoftIISv2" -Class "IIsApplicationPool" -Authentication PacketPrivacy | Where { $_.Name -eq "W3SVC/APPPOOLS/MSExchangeSyncAppPool"}
            $AppPool.Recycle()
            Write-Output "Restarting MSExchangeRPCProxyAppPool on $Identity"
            $AppPool= Get-WMIObject -ComputerName $Identity -Namespace "root\MicrosoftIISv2" -Class "IIsApplicationPool" -Authentication PacketPrivacy | Where { $_.Name -eq "W3SVC/APPPOOLS/MSExchangeRPCProxyAppPool"}
            $AppPool.Recycle()
        }
    } 
}