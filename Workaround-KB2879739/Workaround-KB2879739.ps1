<#
	.SYNOPSIS
	Performs workaround described in KB2879739, fixing Exchange 2013 issues
	after installing MS13-061/KB2874216.

	.LINK
	http://eightwone.com
	http://support.microsoft.com/kb/2879739
	http://support.microsoft.com/kb/2874216

       
   	Michel de Rooij
	michel@eightwone.com
	http://eightwone.com
	
	THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
	RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
	Version 1.02, August 16th, 2013
	
	Revision History
	---------------------------------------------------------------------
	1.0     Initial release
	1.01    Added DependOnService/http
	1.02    Added (re)starting HostControllerService
	
	.EXAMPLE
	.\Workaround-KB2879739.ps1
#>

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Search Foundation for Exchange" -Name "DataDirectory" -Value "$exinstall\Bin\Search\Ceres\HostController\Data" -Force -Type String
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\HostControllerService" -Name "DisplayName" -Value "Microsoft Exchange Search Host Controller" -Force -Type String
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\HostControllerService" -Name "DependOnService" -Value "http" -Force -Type MultiString
Restart-Service HostControllerService
