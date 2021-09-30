<#
    .SYNOPSIS
    Configures Anti-Affinity in Microsoft Failover Clusters to influence fail-over behavior and
    prevent Cluster Groups (e.g. Virtual Machines) from being served by the same host. 

       
   	Michel de Rooij
	michel@eightwone.com
	http://eightwone.com
	
	THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
	RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
	Version 1.0, July 21th, 2013
	
    .DESCRIPTION
	
	This script configures AntiAffinity settings on Cluster Groups using Anti Affinity
    Class Names.
	
	.PARAMETER Cluster
	Name of the Failover Cluster
	
	.PARAMETER Groups
	Name of the Cluster Groups to (re)configure Anti Affinity on

	.PARAMETER Class
	Name of the Anti Affiity class name to use
	
	.PARAMETER Overwrite
	Overwrite Anti Affinity settings for the specified Cluster Groups

	.PARAMETER Clear
	Clear Anti Affinity settings for the specified Cluster Groups
	
    .EXAMPLE
    Configure anti affinity on vluster CLU1 for specified Virtual Machines using class name EX
    .\Configure-AntiAffinity.ps1 -Cluster clu1 -Groups ex1,ex2 -Class EX -Verbose

    Configure anti affinity on vluster CLU1 for specified Virtual Machines using class name PRODEX,
    overwriting any present Anti Affinity class names.
    .\Configure-AntiAffinity.ps1 -Cluster clu1 -Groups ex1,ex2,ex3 -Class PRODEX -Overwrite -Verbose

    Clear anti affinity settings on vluster CLU1 for specified Virtual Machines
    .\Configure-AntiAffinity.ps1 -Cluster clu1 -Groups dc1,dc2,ex1,ex2,ex3 -Clear -Verbose

#>

[cmdletbinding()]
param(
	[parameter(Position=0,Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName="AASet")]
	[parameter(Position=0,Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName="AAClr")]
		[string]$Cluster,
	[parameter(Position=1,Mandatory=$true,ValueFromPipeline=$true,ParameterSetName="AASet")]
	[parameter(Position=1,Mandatory=$true,ValueFromPipeline=$true,ParameterSetName="AAClr")]
		[array]$Groups,
	[parameter(Position=2,Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName="AASet")]
		[string]$Class,
	[parameter(Position=3,Mandatory=$false,ValueFromPipeline=$false,ParameterSetName="AASet")]
		[switch]$Overwrite=$false,
	[parameter(Position=3,Mandatory=$false,ValueFromPipeline=$false,ParameterSetName="AAClr")]
		[switch]$Clear=$false
    )

$ERR_NOMATCHINGVMS= 1002
$ERR_MODULEMISSING= 1001

if (-not (Get-Module FailoverClusters)) {
    if (Get-Module -ListAvailable -Name FailoverClusters) {
        Write-Verbose "Loading Failover Cluster PowerShell Module"
        Import-Module FailoverClusters
    }
    Else {
        Write-Error "Failover Cluster PowerShell module not available"
        Exit $ERR_MODULEMISSING
    }
}

$AAGroup= Get-ClusterGroup -Cluster $Cluster | Where { $Groups -contains $_.Name }

$EmptyCol= New-Object System.Collections.Specialized.StringCollection

ForEach( $Item in $AAGroup) {
    If( $Clear) {
        Write-Verbose "Clearing AntiAffinity on $($Item.Name)"
        $Item.AntiAffinityClassNames= $EmptyCol
    }
    Else {
        $AACol= New-Object System.Collections.Specialized.StringCollection
	    If( $Overwrite) {
            $tmp= $AACol.Add( $Class)
		    $Item.AntiAffinityClassNames= $AACol
	    }
	    Else {
            If( $Item.AntiAffinityClassNames -notcontains $Class) {
                $Item.AntiAffinityClassNames | ForEach { $tmp= $AACol.Add( $_) }
                $tmp= $AACol.Add( $Class)
            	Write-Verbose "AntiAffinity on $($Item.Name) set to $AACol"
                $Item.AntiAffinityClassNames= $AACol
            }
            Else {
            	Write-Warning "AntiAffinity on $($Item.Name) already contains $Class"
            }
    	}
    }
}
