<#
    .SYNOPSIS

    Get-MyMailboxStatistics is a proxy function for the Exchange Mangement Shell Cmdlet of the same name. 
    It uses a Get-StorageLimitStatus helper function to populate the StorageLimitStatus field, which
    remains empty when using Exchange 2013 (by design, see KB2819389). When required, you can extract that 
    function and import it in your own Quota reporting scripts, passing it a
    [Microsoft.Exchange.Management.MapiTasks.Presentation.MailboxStatistics] object (Get-MailboxStatistics objects)
    
    For more information on proxy functions, see 
    http://blogs.msdn.com/b/powershell/archive/2009/01/04/extending-and-or-modifing-commands-with-proxies.aspx

    Michel de Rooij
    michel@eightwone.com
	
    THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
    RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
    Version 1.02, November 21st, 2014

    Thanks to Ryan Mitchell.
 
    .LINK
    http://eightwone.com
    http://support.microsoft.com/kb/2819389

    .NOTES
    Requires Exchange Management Shell, Get-StorageLimitStatus requires mailbox statistics object as input.

    .EXAMPLE
    .\Get-MyMailboxStatistics.ps1 -Database MDB2

    .EXAMPLE 
    Alternative usage is the Get-StorageLimitStatus helper function
    Get-MailboxStatistics -Database MDB2 | Select -ExcludeProperty StorageLimitStatus DisplayName,ItemCount,@{n="StorageLimitStatus"; e={ Get-StorageLimitStatus $_}},LastLogonTime

    Revision History
    --------------------------------------------------------------------------------
    1.0     Initial public release
    1.01    Fixed bug in status logic
    1.02    Fixed bug in unlimited exclusion
            Fixed bug in status determination logic

    .ForwardHelpTargetName Get-MailboxStatistics
    .ForwardHelpCategory Cmdlet

#>


[CmdletBinding(DefaultParameterSetName='Identity')]
param(
    [switch]
    ${IncludeMoveHistory},

    [switch]
    ${IncludeMoveReport},

    [Parameter(ParameterSetName='Identity')]
    [switch]
    ${Archive},

    [Parameter(ParameterSetName='Database', Position=0, ValueFromPipeline=$true)]
    [Microsoft.Exchange.Configuration.Tasks.StoreMailboxIdParameter]
    ${StoreMailboxIdentity},

    [switch]
    ${NoADLookup},

    [Parameter(ParameterSetName='Server')]
    [Parameter(ParameterSetName='Database')]
    [string]
    ${Filter},

    [Parameter(ParameterSetName='Identity', Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [Microsoft.Exchange.Configuration.Tasks.GeneralMailboxOrMailUserIdParameter]
    ${Identity},

    [Parameter(ParameterSetName='Database', Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [Microsoft.Exchange.Configuration.Tasks.DatabaseIdParameter]
    ${Database},

    [Parameter(ParameterSetName='Server', Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [Microsoft.Exchange.Configuration.Tasks.ServerIdParameter]
    ${Server},

    [Microsoft.Exchange.Data.Fqdn]
    ${DomainController}
)

begin
{
    try {
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }
        # Get-MailboxStatistics is classified function, not Cmdlet. See options with: [enum]::getNames('System.Management.Automation.CommandTypes')
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-MailboxStatistics', [System.Management.Automation.CommandTypes]::Function)

        $scriptCmd= {& $wrappedCmd @PSBoundParameters | ForEach-Object{ 
            $_ | Add-Member -MemberType NoteProperty -Name "StorageLimitStatus" -Value (Get-StorageLimitStatus $_) -Force -PassThru 
            }
        }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    } catch {
        throw 
    }
}

process
{
    
    Function Get-StorageLimitStatus {
    Param(
        [Parameter(Mandatory=$True,Position=1)]
        [Microsoft.Exchange.Management.MapiTasks.Presentation.MailboxStatistics]$MbxStat
    )
        $Mailbox= Get-Mailbox $MbxStat.Identity | Select UseDatabaseQuotaDefaults,ProhibitSendQuota,ProhibitSendReceiveQuota,IssueWarningQuota
        If( $Mailbox.UseDatabaseQuotaDefaults) {
            $Lim1= $MbxStat.DatabaseProhibitSendReceiveQuota
            $Lim2= $MbxStat.DatabaseProhibitSendQuota
            $Lim3= $MbxStat.DatabaseIssueWarningQuota
        }
        Else {
            $Lim1= $Mailbox.ProhibitSendReceiveQuota
            $Lim2= $Mailbox.ProhibitSendQuota
            $Lim3= $Mailbox.IssueWarningQuota
        }
        If( $Lim1.IsUnlimited -and $Lim2.IsUnlimited -and $Lim3.IsUnlimited) {
            $res= [Microsoft.Exchange.Data.Mapi.StorageLimitStatus]::NoChecking
        }
        Else {
            $Size= $MbxStat.TotalItemSize.Value
            $res= $null
            If( -not $Lim1.IsUnlimited -and $Size -gt $Lim1) {
                $res= [Microsoft.Exchange.Data.Mapi.StorageLimitStatus]::MailboxDisabled
            }
            Else {
                If( -not $Lim2.IsUnlimited -and $Size -gt $Lim2) {
                    $res= [Microsoft.Exchange.Data.Mapi.StorageLimitStatus]::ProhibitSend
                }
                Else {
                    If( -not $Lim3.IsUnlimited -and $Size -gt $Lim3) {
                        $res= [Microsoft.Exchange.Data.Mapi.StorageLimitStatus]::IssueWarning
                    }
                    Else {
                        $res= [Microsoft.Exchange.Data.Mapi.StorageLimitStatus]::BelowLimit
                    }
                }
            }
        }
        return $res
    }

    try {
        $steppablePipeline.Process($_)
    } catch {
        throw
    }
}

end
{
    try {
        $steppablePipeline.End()
    } catch {
        throw
    }
}
