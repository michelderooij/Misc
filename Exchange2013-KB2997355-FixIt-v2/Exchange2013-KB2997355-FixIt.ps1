# Copyright (c) Microsoft Corporation.  All Rights Reserved.
#
# CFGFixes.ps1
#

Write-Host "Applying fix..."

$baseDirectory = "$Env:ProgramFiles\Microsoft\Exchange Server\V15\ClientAccess\ecp\DDI"
$xamlFile = "RemoteDomains.xaml"
$cfgFile = Join-Path $baseDirectory $xamlFile

Write-Host "Updating XAML..."

$content = Get-Content $cfgFile
$content -Replace '<Variable DataObjectName="RemoteDomain" Name="DomainName" Type="{x:Type s:String}" />','<Variable DataObjectName="RemoteDomain" Name="DomainName" Type="{x:Type s:String}" />    <Variable DataObjectName="RemoteDomain" Name="TargetDeliveryDomain" Type="{x:Type s:Boolean}" />' | Out-File $cfgFile -Force

$content = Get-Content $cfgFile
$content -Replace '<GetListWorkflow Output="Identity, Name, DomainName">','<GetListWorkflow Output="Identity, Name, DomainName, TargetDeliveryDomain">' | Out-File $cfgFile -Force

$content = Get-Content $cfgFile
$content -Replace '<GetObjectWorkflow Output="Identity,Name, DomainName, AllowedOOFType, AutoReplyEnabled,AutoForwardEnabled,DeliveryReportEnabled, NDREnabled,  TNEFEnabled, MeetingForwardNotificationEnabled, CharacterSet, NonMimeCharacterSet">','<GetObjectWorkflow Output="Identity, Name, DomainName, TargetDeliveryDomain, AllowedOOFType, AutoReplyEnabled, AutoForwardEnabled, DeliveryReportEnabled, NDREnabled,  TNEFEnabled, MeetingForwardNotificationEnabled, CharacterSet, NonMimeCharacterSet">' | Out-File $cfgFile -Force

Write-Host "Resetting IIS..."

iisReset /Restart

Write-Host "Completed"