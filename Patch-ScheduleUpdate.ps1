<#
.SYNOPSIS
 ScheduleUpdate.ps1 use to create or update a update schedule in Azure Update management.

.DESCRIPTION
  This script is intended to create or update a update schedule in Azure Update management. 

.PARAMETER ScheduleName
  A string for update schedule name, will append the date time (yyyy-MMdd-hhmm) w/o '-Update' switch 

.PARAMETER Subscription
  A string for Subscription of Automaction account.

.PARAMETER ResourceGroupName
  A string for Resource Group Name of Automaction account.

.PARAMETER AutomationAccountName
  A string for Automaction account Name.

.PARAMETER ServerList
  A string for serverlist path (like "C:\sl.txt") or server names(like "server1,server2").

.PARAMETER Scope
  An array of string for query VMs.

.PARAMETER Tags
  An object of Hashtable for query VMs use tages.
  e.g. @{tag1 = @("tag1","Tag2");tag2 = "value"} in local powershell and Azure runbook

.PARAMETER TagOperators
  An int for tag operator, the default value is 0. (All:0; Any:1)

.PARAMETER StartTime
  A string for start time of the update schedule. 
  e.g. "2022-5-30T21:00"

.PARAMETER AddMinutes
  An int for add minutes to start update schedule, the default value is 10 mins w/o StartTime.

.PARAMETER Update
  A switch to update the update schedule, otherwise will renew a update schedule.

.PARAMETER Duration
  An int for the Patch Window, the default value is 200 mins.

.PARAMETER PreTaskRunbookName
  A string for pretask runbook name.

.PARAMETER PostTaskRunbookName
  A string for posttask runbook name.

.PARAMETER PreTaskRunbookParameter
  An object of Hashtable for pretask runbook.
  e.g. @{param1 = "paramValue";param2 = 3} in local powershell and Azure runbook

.PARAMETER PostTaskRunbookParameter
  An object of Hashtable for posttask runbook.
  e.g. @{param1 = "paramValue";param2 = 3} in local powershell and Azure runbook

.PARAMETER RebootSetting
  An int for reboot setting, the defaule value is 0. (IfRequired:0;Never:1;Always:2;RebootOnly:3)

.PARAMETER IncludedUpdateClassification
  An array int for include update classification, the defaule value is @(1).
  ==========================================================================
  (Critical:1;Security:2;UpdateRollup:4;FeaturePack:8;ServicePack:16;Definition:32;Tools:64;Updates:128)
  e.g. @(1,2,4,8,16,32,64,128) in local powershell
  e.g. [1,2,4,8,16,32,64,128] in Azure runbook

.PARAMETER ExcludedKbNumber
  An array of string for exclude Kb number.
  e.g. @("168934","168935") in local powershell
  e.g. ["168934","168935"] in Azure runbook

.PARAMETER IncludedKbNumber
  An array of string for include Kb number.
  e.g. @("168934","168935") in local powershell
  e.g. ["168934","168935"] in Azure runbook

.EXAMPLE (running locally)
get-help .\ScheduleUpdate.ps1 -Full
Dump this full help

.EXAMPLE (running Azure)
.\ScheduleUpdate.ps1 -ScheduleName FE-Batch1 -Subscription "XXXXXXXXX" -ResourceGroupName "XXXX" -AutomationAccountName "" -Scope ["/subscriptions/XXXXXXXXX/resourceGroups/XXXX"] -Tags @{tag1 = @("tag1","Tag2")} -Update true
Update a update schedule use Azure query

.EXAMPLE (running locally)
.\ScheduleUpdate.ps1 -ScheduleName FE-Batch1 -Subscription "XXXXXXXXX" -ResourceGroupName "XXXX" -AutomationAccountName "PatchingTest" -Scope @("/subscriptions/XXXXXXXXX/resourceGroups/XXXX") -Tags @{tag1 = @("tag1","Tag2")}
Create a update schedule use Azure query

.EXAMPLE (running locally)
.\ScheduleUpdate.ps1 -ScheduleName FE-Batch1 -Subscription "XXXXXXXXX" -ResourceGroupName "XXXX" -AutomationAccountName "PatchingTest" -Scope @("/subscriptions/XXXXXXXXX/resourceGroups/XXXX") -Tags @{tag1 = @("tag1","Tag2")}
Create a update schedule use Azure query

.EXAMPLE (running locally)
.\ScheduleUpdate.ps1 -ScheduleName FE-Batch1 -Subscription "XXXXXXXXX" -ResourceGroupName "XXXX" -AutomationAccountName "PatchingTest" -ServerList ".\sl.txt"
Create a update schedule use Serverlist

.EXAMPLE (running locally)
.\ScheduleUpdate.ps1 -ScheduleName FE-Batch1 -Subscription "XXXXXXXXX" -ResourceGroupName "XXXX" -AutomationAccountName "PatchingTest" -ServerList ".\sl.txt" -PreTaskRunbookName "Runbook" -PreTaskRunbookParameter @{ProbeFile = "probe.txt"} -PostTaskRunbookName "Runbook" -PostTaskRunbookParameter @{ProbeFile = "probe.txt"}
Create a update schedule use Serverlist and add Pre/Post task runbook

#>
#requires -Modules Az.Accounts
#requires -Modules Az.Automation
param(
    [parameter(mandatory=$true)]
    [string]$ScheduleName,

    [parameter(mandatory=$false)]
    [string]$Subscription = "",

    [parameter(mandatory=$false)]
    [string]$ResourceGroupName = "",

    [parameter(mandatory=$false)]
    [string]$AutomationAccountName = "",

    [parameter(mandatory=$false)]
    [string]$ServerList = $null,

    [parameter(mandatory=$false)]
    [string[]]$Scope = $null,

    [parameter(mandatory=$false)]
    [string[]]$Location = $null,

    [parameter(mandatory=$false)]
    [object]$Tags = $null,

    [parameter(mandatory=$false)]
    [int]$TagOperators = 0,

    [parameter(mandatory=$false)]
    [string]$StartTime = $null,

    [parameter(mandatory=$false)]
    [int]$AddMinutes = 0,
    
    [parameter(mandatory=$false)]
    [bool]$Update = $false,

    [parameter(mandatory=$false)]
    [int]$Duration = -1,

    [parameter(mandatory=$false)]
    [string]$PreTaskRunbookName = $null,

    [parameter(mandatory=$false)]
    [string]$PostTaskRunbookName = $null,

    [parameter(mandatory=$false)]
    [object]$PreTaskRunbookParameter = $null,

    [parameter(mandatory=$false)]
    [object]$PostTaskRunbookParameter = $null,

    [parameter(mandatory=$false)]
    [int]$RebootSetting = -1,

    [parameter(mandatory=$false)]
    [int[]]$IncludedUpdateClassification = $null,

    [parameter(mandatory=$false)]
    [String[]]$ExcludedKbNumber = $null,

    [parameter(mandatory=$false)]
    [String[]]$IncludedKbNumber = $null
    
)
<# Parameter def End #>
#******************************************************************************
<#  Global State Configuration Start #>
#******************************************************************************

<#  
    Script Initialization Start 
    This script doesn't need to inherit Global Variable from the parent context. We initialize it as a new Hash object and share between functions to simplify coding.
#>
$errorActionPreference = "Stop"
$Global:ScheduleUpdate = @{}
$Global:ScheduleUpdate['ExitCode'] = 0
$Global:ScheduleUpdate['RunOnAzure'] = 0
#******************************************************************************
<# Function Definitions Start #>
#******************************************************************************
function Get-Servers([string]$serverList){
    <#
        .Synopsis 
            Get servers from a txt file or string.

        .Description
            The function gets the server names in an array from ServerList.

        .PARAMETER serverList
            A file or string for server name.

        .OUTPUTS
            The array of servers.
    #>
    Write-Host "Entering Get-Servers with {$serverList} "
    if($ServerList -eq $null){
        Write-Warning "Please specify ServerList, exit!"
        Exit-WithCode -exitcode 1
    }
    $result = New-Object System.Collections.ArrayList
    if($serverList -like "*.txt"){
        if(-not $serverList.Contains("\")){
            $serverList = Join-Path -Path $here -ChildPath $serverList
        }
        if($(Test-Path -Path $serverList -ErrorAction SilentlyContinue)){
            @(Get-Content $serverList) | %{if(![String]::IsNullOrEmpty($_)){$out = $result.Add($_)}}
        }else{
            Write-Warning "Can't find server list file {$serverList}, Please check!"
            Exit-WithCode -exitcode 1
        }
    }else{
        if(-not $serverList.Contains(",")){
            $out = $result.Add($serverlist)
        }else{
            $result = $serverlist.Split(',')
        }
    }
    Write-Host "Leaving Get-Servers with {$result} "
    # explicitly return an array
    return ,$result
}

function Exit-WithCode ([Int]$exitcode)
{ 
    <#
        .Synopsis 
            Wrapping the exit code when exit script.

        .Description
            The function addresses the exit code in the test or automation environment.

        .PARAMETER exitcode
            The exit code needs to deal with.

        .OUTPUTS
            No output.
    #>
    $Global:ScheduleUpdate.ExitCode = $exitcode
    Exit $exitcode;		
}
<# Function Definitions End #>
#------------------------------------------------------------------------------
#******************************************************************************
<# Main Script Start #>
#******************************************************************************
try
{
    #========Login ============
    if ("AzureAutomation/" -eq $env:AZUREPS_HOST_ENVIRONMENT) {
        Write-Output "This script ScheduleUpdate run on Azure Runbook"
        $AzureContext = (Connect-AzAccount -Identity).context
        $Global:ScheduleUpdate['RunOnAzure'] = 1
    }else{
        Set-StrictMode -Version Latest
        $here = if($MyInvocation.MyCommand.PSObject.Properties.Item("Path") -ne $null){(Split-Path -Parent $MyInvocation.MyCommand.Path)}else{$(Get-Location).Path}
        Write-Output "This script ScheduleUpdate running locally"
        if(Test-Path "$here\azurecontext.json"){
            $AzureContext = Import-AzContext -Path "$here\azurecontext.json"
        }else{
            $AzureContext = Connect-AzAccount -Subscription $Subscription -ErrorAction Stop
            Save-AzContext -Path "$here\azurecontext.json"
        }
    }
    $time = Get-Date
    #========Set start time and schedule ============
    if(![string]::IsNullOrEmpty($StartTime)){
        $startDateTime = [DateTimeOffset]$StartTime
    }else{
        $startDateTime = [DateTime]::Now
        if($AddMinutes -eq 0){
            $AddMinutes = 10
        }
    }
    $startDateTime = $startDateTime.AddMinutes($AddMinutes)
    $TimeZone = ([System.TimeZoneInfo]::Utc).Id
    #========Set VMs ============
    $azureVMs = @()
    if(![string]::IsNullOrEmpty($ServerList)){        
        Write-Output "Get VM ids from $ServerList"
        $servers = Get-Servers $ServerList 
        $servers | %{ $azureVMs += (Get-AzVM -Name $_)}
        $azureVMs = $azureVMs.Id
    }    
    #===== deal with Update ===========
    if($Update -eq $false){
        $ScheduleName = "$($ScheduleName)_$((get-date).ToString('yyyy-MMdd-hhmm'))"
        Write-Output "New schedule use the name $ScheduleName $ResourceGroupName $AutomationAccountName"
        $schedule = New-AzAutomationSchedule -Name $ScheduleName -StartTime $startDateTime -OneTime -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -TimeZone $TimeZone
        if($RebootSetting -eq -1){
            $RebootSetting = 0
        }
        if($IncludedUpdateClassification -eq $null){
            $IncludedUpdateClassification = @(1)
        }
        if($Duration -eq -1){
            $Duration = 120
        }
        $AzureQuery = $null
        if(($Scope -ne $null -and $Scope.Count -gt 0)){
            Write-Output "Create AzureQuery use the name $Scope $tags $ResourceGroupName $AutomationAccountName $TagOperators"
            if($Global:ScheduleUpdate['RunOnAzure'] -eq 1 -and $tags -ne $null -and $($tags.GetType().Name) -eq "string"){
                $tags = Invoke-Expression $tags
            }
            $AzureQuery = New-AzAutomationUpdateManagementAzureQuery -ResourceGroupName $ResourceGroupName `
                                               -AutomationAccountName $AutomationAccountName `
                                               -Scope $Scope `
											   -Location $Location `
                                               -Tag $tags `
                                               -FilterOperator $TagOperators 
        }
    }else{
        Write-Output "Get schedule use the name $ScheduleName $ResourceGroupName $AutomationAccountName with startDateTime $startDateTime Tags: $Tags"
        #$schedule = Get-AzAutomationSchedule -Name $ScheduleName -ResourceGroupName $resourceGroupName -AutomationAccountName  $automationAccountName        
        $updateConfiguration = Get-AzAutomationSoftwareUpdateConfiguration -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $ScheduleName
        if($updateConfiguration -eq $null){
            Write-Output "Can't find update configuration with schedule name $ScheduleName, please check!"
            exit 1
        }else{
            Write-Output "Find update configuration with schedule name $ScheduleName : $updateConfiguration "
        }
        $schedule = $updateConfiguration.ScheduleConfiguration
        if(-not[string]::IsNullOrEmpty($startDateTime)){
            Write-Output "Overwrite StartTime: $($schedule.StartTime) to $startDateTime"
            $schedule.StartTime = $startDateTime
        }
        $schedule.Name = $ScheduleName
        #===== VMs ==
        if($azureVMs.Count -eq 0 -and $updateConfiguration.UpdateConfiguration.AzureVirtualMachines.Count -gt 0){
            Write-Output "Copy AzureVMResourceId: $($updateConfiguration.UpdateConfiguration.AzureVirtualMachines)"
            $azureVMs = $updateConfiguration.UpdateConfiguration.AzureVirtualMachines
        }else{
            if($azureVMs.Count -gt 0){
                Write-Output "Overwrite AzureVMs: $($azureVMs)"
            }
        }        
        if(![string]::IsNullOrEmpty($Tags)){
            if($Global:ScheduleUpdate['RunOnAzure'] -eq 1 -and $Tags -ne $null -and $($Tags.GetType().Name) -eq "string"){
                $Tags = Invoke-Expression $Tags
            }            
            Write-Output "Overwrite Tags"
            Write-Output "Overwrite Tags: $($result.UpdateConfiguration.Targets.AzureQueries[0].TagSettings.Tags) to $Tags"
            $updateConfiguration.UpdateConfiguration.Targets.AzureQueries[0].TagSettings.Tags.Clear()
            foreach($key in $Tags.Keys){
                #$Tag.Add($key, $Tags[$key])
                $updateConfiguration.UpdateConfiguration.Targets.AzureQueries[0].TagSettings.Tags.Add($key, $Tags[$key])
            }
            #$updateConfiguration.UpdateConfiguration.Targets.AzureQueries[0].TagSettings.Tags = $Tag
        }else{
            if($updateConfiguration.UpdateConfiguration.Targets.AzureQueries -ne $null){
                Write-Output "Copy Tags from: $($updateConfiguration.UpdateConfiguration.Targets.AzureQueries[0].TagSettings.Tags)"
            }
        }
        if($updateConfiguration.UpdateConfiguration.Targets.AzureQueries -ne $null -and $TagOperators -ne $($result.UpdateConfiguration.Targets.AzureQueries[0].TagSettings.FilterOperator.value__)){
            Write-Output "Overwrite TagOperators: $($result.UpdateConfiguration.Targets.AzureQueries[0].TagSettings.FilterOperator.value__) to $TagOperators"
            $updateConfiguration.UpdateConfiguration.Targets.AzureQueries[0].TagSettings.FilterOperator = $TagOperators
        }else{
            if($updateConfiguration.UpdateConfiguration.Targets.AzureQueries -ne $null){
                Write-Output "Copy TagOperators from: $($result.UpdateConfiguration.Targets.AzureQueries[0].TagSettings.FilterOperator.value__)"
            }
        }
        if((![string]::IsNullOrEmpty($Scope) -or ![string]::IsNullOrEmpty($Location)) -and $updateConfiguration.UpdateConfiguration.Targets.AzureQueries -ne $null){
            Write-Output "Overwrite Scope: $($updateConfiguration.UpdateConfiguration.Targets.AzureQueries[0]) to $Scope or $Location"
            #$updateConfiguration.UpdateConfiguration.Targets.AzureQueries = $Scope
            if ([string]::IsNullOrEmpty($Scope)) {$Scope = $updateConfiguration.UpdateConfiguration.Targets.AzureQueries[0].Scope}
		    if ([string]::IsNullOrEmpty($Location)) {$Location = $updateConfiguration.UpdateConfiguration.Targets.AzureQueries[0].Locations}
			$AzureQuery = New-AzAutomationUpdateManagementAzureQuery -ResourceGroupName $ResourceGroupName `
                                               -AutomationAccountName $AutomationAccountName `
                                               -Scope $Scope `
											   -Location $Location `
                                               -Tag $Tags `
                                               -FilterOperator $TagOperators
        }else{
            Write-Output "processing AzureQuery: $($updateConfiguration.UpdateConfiguration.Targets.AzureQueries)"
            $AzureQuery = $updateConfiguration.UpdateConfiguration.Targets.AzureQueries
        }
        #===== Runbook ==
        if([string]::IsNullOrEmpty($PreTaskRunbookName) -and $updateConfiguration.Tasks.PreTask -ne $null -and $updateConfiguration.Tasks.PreTask.source -ne $null){
            Write-Output "Copy PreTaskRunbookName: $($updateConfiguration.Tasks.PreTask.source)"
            $PreTaskRunbookName = $updateConfiguration.Tasks.PreTask.source
            if($PreTaskRunbookParameter -eq $null -and $updateConfiguration.Tasks.PreTask.parameters -ne $null){
                Write-Output "Copy PreTaskRunbookParameter: $($updateConfiguration.Tasks.PreTask.parameters)"
                $PreTaskRunbookParameter = $updateConfiguration.Tasks.PreTask.parameters
            }else{
                if($PreTaskRunbookParameter -ne $null){
                    Write-Output "Overwrite PreTaskRunbookParameter: $($PreTaskRunbookParameter)"
                }
            }
        }else{
            if(![string]::IsNullOrEmpty($PreTaskRunbookName)){
                Write-Output "Overwrite PreTaskRunbookName: $($PreTaskRunbookName)"
            }
        }
        if([string]::IsNullOrEmpty($PostTaskRunbookName) -and $updateConfiguration.Tasks.PostTask -ne $null -and $updateConfiguration.Tasks.PostTask.source -ne $null){
            Write-Output "Copy PostTaskRunbookName: $($updateConfiguration.Tasks.PostTask.source)"
            $PostTaskRunbookName = $updateConfiguration.Tasks.PostTask.source
            if($PostTaskRunbookParameter -eq $null -and $updateConfiguration.Tasks.PostTask.parameters -ne $null){
                Write-Output "Copy PostTaskRunbookParameter: $($updateConfiguration.Tasks.PostTask.parameters)"
                $PostTaskRunbookParameter = $updateConfiguration.Tasks.PostTask.parameters
            }else{
                if($PostTaskRunbookParameter -ne $null){
                    Write-Output "Overwrite PostTaskRunbookParameter: $($PostTaskRunbookParameter)"
                }
            }
        }else{
            if(![string]::IsNullOrEmpty($PostTaskRunbookName)){
                Write-Output "Overwrite PostTaskRunbookName: $($PostTaskRunbookName)"
            }
        }
        #===== Duration ==
        if($Duration -eq -1){
            Write-Output "Copy Duration: $($updateConfiguration.UpdateConfiguration.Duration.TotalMinutes)"
            $Duration = $updateConfiguration.UpdateConfiguration.Duration.TotalMinutes
        }else{
            Write-Output "Overwrite Duration: $Duration"
        }
        #===== Windows ==
        if($RebootSetting -eq -1 -and $RebootSetting -ne $updateConfiguration.UpdateConfiguration.Windows.rebootSetting.value__){
            Write-Output "Copy rebootSetting: $($updateConfiguration.UpdateConfiguration.Windows.rebootSetting.value__)"
            $RebootSetting = $updateConfiguration.UpdateConfiguration.Windows.rebootSetting.value__
        }else{
            if($RebootSetting -ne -1){
                Write-Output "Overwrite RebootSetting: $RebootSetting"
            }
        }
        if([string]::IsNullOrEmpty($IncludedUpdateClassification) -and $updateConfiguration.UpdateConfiguration.Windows.IncludedUpdateClassifications -ne $null){
            foreach($i in $updateConfiguration.UpdateConfiguration.Windows.IncludedUpdateClassifications){
                Write-Output "Copy IncludedUpdateClassification: $($i.value__)"
                $IncludedUpdateClassification += $i.value__
            }
        }else{
            if(![string]::IsNullOrEmpty($IncludedUpdateClassification)){
                Write-Output "Overwrite IncludedUpdateClassification: $IncludedUpdateClassification"
            }
        }
        if([string]::IsNullOrEmpty($ExcludedKbNumber) -and $updateConfiguration.UpdateConfiguration.Windows.ExcludedKbNumbers -ne $null){
            foreach($i in $updateConfiguration.UpdateConfiguration.Windows.ExcludedKbNumbers){
                Write-Output "Copy ExcludedKbNumber: $($i.value__)"
                $ExcludedKbNumber += $i.value__
            }
        }else{
            if(![string]::IsNullOrEmpty($ExcludedKbNumber)){
                Write-Output "Overwrite ExcludedKbNumber: $ExcludedKbNumber"
            }
        }
        if([string]::IsNullOrEmpty($IncludedKbNumber) -and $updateConfiguration.UpdateConfiguration.Windows.IncludedKbNumbers -ne $null){
            foreach($i in $updateConfiguration.UpdateConfiguration.Windows.IncludedKbNumbers){
                Write-Output "Copy IncludedKbNumber: $($i.value__)"
                $IncludedKbNumber += $i.value__
            }
        }else{
            if(![string]::IsNullOrEmpty($IncludedKbNumber)){
                Write-Output "Overwrite IncludedKbNumber: $IncludedKbNumber"
            }
        }
    }
    
    #========Set Update schedule ============
    $d = New-TimeSpan -Minutes $Duration
    Write-Output "Schedule update config $ScheduleName at $startDateTime"
    if(![string]::IsNullOrEmpty($PreTaskRunbookName) -and ![string]::IsNullOrEmpty($PostTaskRunbookName)){
        if($Global:ScheduleUpdate['RunOnAzure'] -eq 1 -and $PreTaskRunbookParameter -ne $null -and $($PreTaskRunbookParameter.GetType().Name) -eq "string"){
            $PreTaskRunbookParameter = Invoke-Expression $PreTaskRunbookParameter
        }
        if($Global:ScheduleUpdate['RunOnAzure'] -eq 1 -and $PostTaskRunbookParameter -ne $null -and $($PostTaskRunbookParameter.GetType().Name) -eq "string"){
            $PostTaskRunbookParameter = Invoke-Expression $PostTaskRunbookParameter
        }
        Write-Output "Setup AzAutomationSoftwareUpdateConfiguration with PreTask $PreTaskRunbookName and PostTask $PostTaskRunbookName"
        $result = New-AzAutomationSoftwareUpdateConfiguration -Schedule $schedule -Windows `
                    -AzureVMResourceId $azureVMs -AzureQuery $AzureQuery -Duration $d `
                    -RebootSetting $RebootSetting -IncludedUpdateClassification $IncludedUpdateClassification `
                    -ExcludedKbNumber $ExcludedKbNumber -IncludedKbNumber $IncludedKbNumber `
                    -PreTaskRunbookName $PreTaskRunbookName -PreTaskRunbookParameter $PreTaskRunbookParameter `
                    -PostTaskRunbookName $PostTaskRunbookName -PostTaskRunbookParameter  $PostTaskRunbookParameter  `
                    -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName
    }elseif(![string]::IsNullOrEmpty($PreTaskRunbookName)){
        if($Global:ScheduleUpdate['RunOnAzure'] -eq 1 -and $PreTaskRunbookParameter -ne $null -and $($PreTaskRunbookParameter.GetType().Name) -eq "string"){
            $PreTaskRunbookParameter = Invoke-Expression $PreTaskRunbookParameter
        }
        Write-Output "Setup AzAutomationSoftwareUpdateConfiguration with PreTask $PreTaskRunbookName"
        $result = New-AzAutomationSoftwareUpdateConfiguration -Schedule $schedule -Windows `
                    -AzureVMResourceId $azureVMs -AzureQuery $AzureQuery -Duration $d `
                    -RebootSetting $RebootSetting -IncludedUpdateClassification $IncludedUpdateClassification `
                    -ExcludedKbNumber $ExcludedKbNumber -IncludedKbNumber $IncludedKbNumber `
                    -PreTaskRunbookName $PreTaskRunbookName -PreTaskRunbookParameter $PreTaskRunbookParameter `
                    -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName
    }elseif(![string]::IsNullOrEmpty($PostTaskRunbookName)){
        if($Global:ScheduleUpdate['RunOnAzure'] -eq 1 -and $PostTaskRunbookParameter -ne $null -and $($PostTaskRunbookParameter.GetType().Name) -eq "string"){
            $PostTaskRunbookParameter = Invoke-Expression $PostTaskRunbookParameter
        }
        Write-Output "Setup AzAutomationSoftwareUpdateConfiguration with PostTask $PostTaskRunbookName"
        $result = New-AzAutomationSoftwareUpdateConfiguration -Schedule $schedule -Windows `
                    -AzureVMResourceId $azureVMs -AzureQuery $AzureQuery -Duration $d `
                    -RebootSetting $RebootSetting -IncludedUpdateClassification $IncludedUpdateClassification `
                    -ExcludedKbNumber $ExcludedKbNumber -IncludedKbNumber $IncludedKbNumber `
                    -PostTaskRunbookName $PostTaskRunbookName -PostTaskRunbookParameter $PostTaskRunbookParameter  `
                    -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName
    }else{
	if($AzureQuery -ne $null){
        Write-Output "Setup AzAutomationSoftwareUpdateConfiguration with AzureQuery $AzureQuery"
        $result = New-AzAutomationSoftwareUpdateConfiguration -Schedule $schedule -Windows -AzureVMResourceId $azureVMs `
                    -AzureQuery $AzureQuery -Duration $d -RebootSetting $RebootSetting -IncludedUpdateClassification $IncludedUpdateClassification `
                    -ExcludedKbNumber $ExcludedKbNumber -IncludedKbNumber $IncludedKbNumber -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName
	}else{
        Write-Output "Setup AzAutomationSoftwareUpdateConfiguration with Schedule $schedule"
	    $result = New-AzAutomationSoftwareUpdateConfiguration -Schedule $schedule -Windows -AzureVMResourceId $azureVMs `
		    -Duration $d -RebootSetting $RebootSetting -IncludedUpdateClassification $IncludedUpdateClassification `
            -ExcludedKbNumber $ExcludedKbNumber -IncludedKbNumber $IncludedKbNumber -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName
	}
}
	Write-Output "Created schedule name: $ScheduleName!"
    Write-Output "Completed the task during $($(Get-Date) - $time) at $time!"
}
catch
{
    Write-Error "Exception: $_"
    throw "Exception: $_"
}
finally
{
}

#------------------------------------------------------------------------------

<# Main Script End #>