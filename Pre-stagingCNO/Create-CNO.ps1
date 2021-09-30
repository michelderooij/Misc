<#
    .SYNOPSIS
    Pre-stages a Cluster Name Object (CNO) definition, required to support restrive environments or Exchange 2013
    when setting up Database Availability Groups (DAG).
   
   	Michel de Rooij
	michel@eightwone.com
	http://eightwone.com
	
	THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
	RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
	Version 1.1, December 20th, 2012
	
    .DESCRIPTION
	
	This script pre-stages a Cluster Name Object (CNO).
	
	.PARAMETER Identity
	Name of the CNO to create
	
	.PARAMETER Computers
	Name of the (computer) account to grant permission on the CNO. When omitted,
	the Exchange Trusted Subsystem will be granted permissions.
	
	.PARAMETER OU
	OU where the CNO should be created
	
    .EXAMPLE
    Create CNO DAG1 in 
    .\Create-CNO.ps1 -CNO DAG1 -OU cn=Computers,dc=contoso,dc=com
	
#>

[cmdletbinding()]
param(
	[parameter(Position=0,Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName="CNO")]
		[string]$Identity,
	[parameter(Position=1,Mandatory=$false,ValueFromPipeline=$false,ParameterSetName="CNO")]
		[array]$Computers,
	[parameter(Position=2,Mandatory=$false,ValueFromPipeline=$false,ParameterSetName="CNO")]
		[string]$OU
    )

Function get-DN{
	param(
		[string]$strName
	)
	$ADSearch= New-Object System.DirectoryServices.DirectorySearcher([ADSI]"")
	$ADSearch.Filter= "(cn=$strName)"
	$Result= $ADSearch.FindOne()
	If( $Result) {
		return $Result.getDirectoryEntry().distinguishedName
	}
	else {
		return $null
	}
}

##################################################
# main
##################################################

#Requires -Version 2.0

If (Get-PsSnapin -Name Microsoft.Exchange.Management.PowerShell.Admin -ErrorAction SilentlyContinue) {
	Write-Error "Exchange Snapin not loaded"
	Exit
}


If( -not $OU) {
	$DN= ([ADSI]"").distinguishedName
	$OU= ( [ADSI]"LDAP://<WKGUID=aa312825768811d1aded00c04fd8d5cd,$DN>").distinguishedName
	Write-Verbose "Using Default Computers container: $OU"
}
else {
	If( !( Get-OrganizationalUnit $OU)) {
		Write-Error "OU $OU doesn't exist"
		Exit
	}
}
$objOU= [ADSI]("LDAP://"+ $OU)

$dn= get-DN $Identity

If( -not $dn) {
	Write-Verbose "Creating computer object $Identity in $objOU"
	$Computer= $objOU.create("Computer", "CN=$Identity")
	$Computer.Put("SamAccountName", "$Identity$")
	$Computer.Put("Description", "$Identity CNO")
	$Computer.Put("userAccountControl", 4130)
	$Computer.SetInfo()
	$dn= "cn=$Identity,"+ $OU
	Write-Verbose "Created computer object $dn"
}
else {
	Write-Warning "CNO $Identity already exists"
}

$CNO= [ADSI]("LDAP://$dn")
$ACL= $CNO.psbase.ObjectSecurity

If ($Computers) {
	If( $Computers -is [array]) {	
		ForEach( $Computer in $Computers) {
			Write-Verbose "Adding permissions on CNO for $Computer"
			Add-AdPermission -Identity "$dn" -User "$($Computer)$" -AccessRights GenericAll
		}
	}
	else {
		Write-Verbose "Adding permissions on CNO for $strComputers"
		Add-AdPermission -Identity "$dn" -User $Computers -AccessRights GenericAll
	}
}
else {
	Write-Verbose "Adding permissions on CNO for Exchange Trusted Subsystem"
	Add-AdPermission -Identity "$dn" -User "Exchange Trusted Subsystem" -AccessRights GenericAll
}