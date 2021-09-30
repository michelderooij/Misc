<#
	.SYNOPSIS
	Improved FixIt script for KB2997355.
    Parts taken from original Exchange2013-KB2997355-FixIt.ps1

	.LINK
	http://eightwone.com
	http://support.microsoft.com/kb/2997355
       
   	Michel de Rooij
	michel@eightwone.com
	http://eightwone.com
	
	THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
	RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
	Version 1.0, September 2nd, 2014
	
	Revision History
	---------------------------------------------------------------------
	1.0     Initial release
	
	.EXAMPLE
	.\Exchange2013-KB2997355-FixIt-v2.ps1
#>

Write-Host "Applying Exchange2013-KB2997355-FixIt-v2 (KB2997355, Exchange Online Mailbox Management Fix)"

$exchangeInstallPath = get-itemproperty -path HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup -ErrorAction SilentlyContinue
if ($exchangeInstallPath -ne $null -and (Test-Path $exchangeInstallPath.MsiInstallPath)) {
    $cfgFile = Join-Path (Join-Path $exchangeInstallPath.MsiInstallPath "ClientAccess\ecp\DDI") "RemoteDomains.xaml"
    If( Test-Path $cfgfile) {
        Write-Host "Updating XAML file $cfgfile .."
        $content= Get-Content $cfgFile
        $content= $content -Replace '<Variable DataObjectName="RemoteDomain" Name="DomainName" Type="{x:Type s:String}" />','<Variable DataObjectName="RemoteDomain" Name="DomainName" Type="{x:Type s:String}" />    <Variable DataObjectName="RemoteDomain" Name="TargetDeliveryDomain" Type="{x:Type s:Boolean}" />' 
        $content= $content -Replace '<GetListWorkflow Output="Identity, Name, DomainName">','<GetListWorkflow Output="Identity, Name, DomainName, TargetDeliveryDomain">'
        $content= $content -Replace '<GetObjectWorkflow Output="Identity,Name, DomainName, AllowedOOFType, AutoReplyEnabled,AutoForwardEnabled,DeliveryReportEnabled, NDREnabled,  TNEFEnabled, MeetingForwardNotificationEnabled, CharacterSet, NonMimeCharacterSet">','<GetObjectWorkflow Output="Identity, Name, DomainName, TargetDeliveryDomain, AllowedOOFType, AutoReplyEnabled, AutoForwardEnabled, DeliveryReportEnabled, NDREnabled,  TNEFEnabled, MeetingForwardNotificationEnabled, CharacterSet, NonMimeCharacterSet">'
        $content | Out-File $cfgFile -Force
        Write-Host "Restarting IIS .."
        iisReset /Restart /NoForce
    }
    Else {
        Write-Error "XAML file not found"
    }
}
Else {
    Write-Error 'KB2997355: Unable to locate Exchange install path'
}
