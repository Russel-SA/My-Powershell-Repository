function Test-Command {
    <#
    .Synopsis
        Test-Command checks commands for consistency.
    .Description
        Test-Command checks commands for consistency.
        
        Test-Command run a series of static analysis rules on your script, and helps you see if there's anything to improve.
        
        It will not run any script, just look at the information about the script, like it's help, command metadata, or the script content itself.                
    .Example
        Get-Module ScriptCop | Test-Command
    .Example
        Get-Command -Type Cmdlet | Test-Command
    .Example
        Get-Command Get-Command | Test-Command
    .Link
        about_ScriptCop_rules
    #>
    [CmdletBinding(DefaultParameterSetName='Command')]
    param(
    # The command or module to test.  If the object is not a module info or command
    # info, it will not work.
    [Parameter(ValueFromPipeline=$true,Mandatory=$true,Position=0,ParameterSetName='Command')]
    [ValidateScript({
        if ($_ -is [Management.Automation.CommandInfo]) { return $true }
        if ($_ -is [Management.Automation.PSModuleInfo]) { return $true }
        if ($_ -is [IO.FileInfo]) { return $true }
        if ($_ -is [string]) { return $true }
        throw "Input must either be a command, a module, a file, or a name"
    })]
    $Command,
    
    # A script block containing functions, for instance: function foo {}.  
    # Script Blocks that do not contain functions will be ignored.
    [Parameter(Mandatory=$true,ParameterSetName='ScriptBlock',Position=0)]
    [ScriptBlock]
    $ScriptBlock,
    
    # The scriptcop 'patrol' (list of rules) to run   
    #|MaxLength 255
    #|Options Get-ScriptCopPatrol | Select-Object -ExpandProperty Name
    [string]$Patrol,            
    
    # The name of the rule to run
    #|Options Get-ScriptCopRule | Select-Object -ExpandProperty Name
    [String[]]$Rule,
    
    # Rules to avoid running.
    #|Options Get-ScriptCopRule | Select-Object -ExpandProperty Name
    [String[]]$ExcludedRule    
    )
    
    begin {        
        Set-StrictMode -Off       
        
        $CommandMetaData = @()  
        $ModuleMetaData = @()
        
        function WriteScriptCopError{
            param([switch]$IsModuleError)        
            
            if ($ScriptCopError) {
                foreach ($e in $ScriptCopError) {
                    if (-not $e) { continue }                    
                    $result = New-Object PSObject -Property @{
                        Rule = if ($IsModuleError) { $Module } else { $testCmd } 
                        Problem = $e
                        ItemWithProblem = if ($IsModuleError) { $ModuleInfo} else { $CommandInfo } 
                    }
                    $result.psObject.TypeNames.Add("ScriptCopError")
                    $result
                }
            }        
        }
        
        $progressId = Get-Random
    }
    
    process {
        
    
        Write-Progress "Collecting Commands" "$command " -Id $progressId
        if ($psCmdlet.ParameterSetName -eq 'Command') {
            if ($command -is [string]) {
                $cmds = @(Get-Command $command -ErrorAction Silentlycontinue)
            } elseif ($command -is [Management.Automation.PSModuleInfo]) {
                $cmds = @($command.ExportedFunctions.Values) + $command.ExportedCmdlets.Values
                $ModuleMetaData += $command
            } elseif ($command -is [Management.Automation.CommandInfo]) {
                $cmds = @($command)
            } elseif ($command -is [IO.FileInfo]) {
                $cmds = @(Get-Command $command.FullName)
            } 
        } elseif ($psBoundParameters.Scriptblock) {
            $functionOnly = Get-FunctionFromScript -ScriptBlock $psBoundParameters.ScriptBlock            
            $cmds = @()
            foreach ($f in $functionOnly) {
                . ([ScriptBlock]::Create($f))
                $matched = $f -match "function ((\w+-\w+)|(\w+))"
                if ($matched -and $matches[1]) {
                    $cmds+=Get-Command $matches[1]
                }                        
            }
        }       
        
        if ($cmds) {
            Write-Progress "Collecting Command Details" " " -Id $progressId
            $c = 0 
            foreach ($cmd in $cmds) {
                $c++
                $perc = $c * 100 / $cmds.Count                
                Write-Progress "Collecting Command Details" "$cmd" -PercentComplete $perc -Id $progressId
                $help = $cmd | Get-Help  
                $CommandMetaData += @{
                    Command = $cmd
                    Function = $(if ($cmd -is [Management.Automation.FunctionInfo]) { $cmd })
                    Application = $(if ($cmd -is [Management.Automation.ApplicationInfo]) { $cmd })
                    ExternalScript = $(if ($cmd -is [Management.Automation.ExternalScriptInfo]) { $cmd })
                    Cmdlet = $(if ($cmd -is [Management.Automation.CmdletInfo]) { $cmd })
                    Help = $(if ($help -and $help -isnot [string]) { $help })
                    Tokens = $(
                        if ($cmd -is [Management.Automation.FunctionInfo]) {
                            [Management.Automation.PSParser]::Tokenize($cmd.scriptblock,[ref]$null)
                        } elseif ($cmd -is [Management.Automation.ExternalScriptInfo]) {
                            [Management.Automation.PSParser]::Tokenize($cmd.scriptcontents,[ref]$null)
                        }
                    )
                    Text = $(
                        if ($cmd -is [Management.Automation.FunctionInfo]) {
                            "function $($cmd.Name) {
                                $($cmd.definition)
                            }"
                        } elseif ($cmd -is [Management.Automation.ExternalScriptInfo]) {
                            $cmd.scriptcontents
                        }
                    )
                }
            }
            Write-Progress "Collecting Command Details" " " -ID $progressId 
        }                                                                  
    }
    
    end {
        Write-Progress 'Filtering Rules' ' ' -Id $progressId              
        
        $currentRules = @{} + $script:ScriptCopRules
        
        $RuleNameMatch = { 
            $Rule -contains $_.Name -or
            $Rule -contains $_.Name.Replace(".ps1","")
        }
        
        if ($Rule) {
            $currentRules.TestCommandInfo = @($currentRules.TestCommandInfo | Where-Object $RuleNameMatch)
            $currentRules.TestCmdletInfo = @($currentRules.TestCmdletInfo | Where-Object $RuleNameMatch)
            $currentRules.TestScriptInfo = @($currentRules.TestScriptInfo | Where-Object $RuleNameMatch)
            $currentRules.TestFunctionInfo = @($currentRules.TestFunctionInfo | Where-Object $RuleNameMatch)
            $currentRules.TestApplicationInfo=  @($currentRules.TestApplicationInfo | Where-Object $RuleNameMatch)
            $currentRules.TestModuleInfo = @($currentRules.TestModuleInfo | Where-Object $RuleNameMatch)
            $currentRules.TestScriptToken = @($currentRules.TestScriptToken | Where-Object $RuleNameMatch)
            $currentRules.TestHelpContent = @($currentRules.TestHelpContent | Where-Object $RuleNameMatch)
        }
        
        $ExcludedRuleNotMatch = { 
            $ExcludedRule -notcontains $_.Name -or
            $ExcludedRule -notcontains $_.Name.Replace(".ps1","")
        }
        
        if ($ExcludedRule) {
            $currentRules.TestCommandInfo = @($currentRules.TestCommandInfo | Where-Object $ExcludedRuleNotMatch)
            $currentRules.TestCmdletInfo = @($currentRules.TestCmdletInfo | Where-Object $ExcludedRuleNotMatch)
            $currentRules.TestScriptInfo = @($currentRules.TestScriptInfo | Where-Object $ExcludedRuleNotMatch)
            $currentRules.TestFunctionInfo = @($currentRules.TestFunctionInfo | Where-Object $ExcludedRuleNotMatch)
            $currentRules.TestApplicationInfo=  @($currentRules.TestApplicationInfo | Where-Object $ExcludedRuleNotMatch)
            $currentRules.TestModuleInfo = @($currentRules.TestModuleInfo | Where-Object $ExcludedRuleNotMatch)
            $currentRules.TestScriptToken = @($currentRules.TestScriptToken | Where-Object $ExcludedRuleNotMatch)
            $currentRules.TestHelpContent = @($currentRules.TestHelpContent | Where-Object $ExcludedRuleNotMatch)
        }
        
        if ($patrol) {
            $commandRules = Get-ScriptCopPatrol -Name $patrol | 
                Select-Object -ExpandProperty CommandRule -ErrorAction SilentlyContinue
            $moduleRules = Get-ScriptCopPatrol -Name $patrol | 
                Select-Object -ExpandProperty ModuleRule -ErrorAction SilentlyContinue
            
            $patrolCommandMatch = $RuleNameMatch = { 
                $commandRules -contains $_.Name -or
                $commandRules -contains $_.Name.Replace(".ps1","")
            }
            
            $patrolModuleMatch = $RuleNameMatch = { 
                $moduleRules -contains $_.Name -or
                $moduleRules -contains $_.Name.Replace(".ps1","")
            }
            
            $currentRules.TestCommandInfo = @($currentRules.TestCommandInfo | Where-Object $patrolCommandMatch)
            $currentRules.TestCmdletInfo = @($currentRules.TestCmdletInfo | Where-Object $patrolCommandMatch)
            $currentRules.TestScriptInfo = @($currentRules.TestScriptInfo | Where-Object $patrolCommandMatch)
            $currentRules.TestFunctionInfo = @($currentRules.TestFunctionInfo | Where-Object $patrolCommandMatch)
            $currentRules.TestApplicationInfo=  @($currentRules.TestApplicationInfo | Where-Object $patrolCommandMatch)
            $currentRules.TestModuleInfo = @($currentRules.TestModuleInfo | Where-Object $patrolModuleMatch)
            $currentRules.TestScriptToken = @($currentRules.TestScriptToken | Where-Object $patrolCommandMatch)
            $currentRules.TestHelpContent = @($currentRules.TestHelpContent | Where-Object $patrolCommandMatch)
        }
                
        Write-Progress "Running ScriptCop" "Validating Modules" -Id $ProgressId       
        if ($currentRules.TestModuleInfo) {
            $c = 0
            $ruleCount = @($currentRules.TestModuleInfo).Count
            foreach ($module in $currentRules.TestModuleInfo){                        
                $c++
                $perc  = $c * 100 / $ruleCount
                Write-Progress "Running ScriptCop" "Validating Modules - $($module.Name)" -PercentComplete $perc -Id $ProgressId
                if ($scriptCopError) {$scriptCopError = $null }
                $ModuleMetaData | 
                    ForEach-Object {
                        $moduleInfo = $_
                        $null = $_ | 
                            & $Module -ErrorAction SilentlyContinue -ErrorVariable ScriptCopError
                        
                        WriteScriptCopError -IsModuleError 
                        
                    }
                    
                    
            }        
        }                                                        
        
        #region Validating Commands        
        
        Write-Progress "Running ScriptCop" "Validating Command Metadata" -Id $ProgressId               
        if ($currentRules.TestCommandInfo) {
            $c = 0
            $ruleCount = @($currentRules.TestCommandInfo).Count
            foreach ($testCmd in $currentRules.TestCommandInfo){                        
                $c++
                $perc  = $c * 100 / $RuleCount
                Write-Progress "Running ScriptCop" "Validating Command Metadata - $($testCmd.Name)" -Id $ProgressId -PercentComplete $perc
                if ($scriptCopError) {$scriptCopError = $null }
                $CommandMetaData | 
                    Where-Object { $_.Command } |
                    ForEach-Object { 
                        $commandInfo = $_.Command 
                        $null = $commandInfo | 
                            & $testCmd -ErrorAction SilentlyContinue -ErrorVariable ScriptCopError
                        
                        WriteScriptCopError                        
                    }
                    
                                    
            }        
        }
            
        #endregion Validating Commands        

        #region Validating Cmdlets        
        Write-Progress "Running ScriptCop" "Validating Cmdlet Metadata" -Id $ProgressId 
                
        if ($currentRules.TestCmdletInfo) {
            $c = 0
            $ruleCount = @($currentRules.TestCmdletInfo).Count
            foreach ($testCmd in $currentRules.TestCmdletInfo){                        
                $c++
                $perc  = $c * 100 / $ruleCount
                Write-Progress "Running ScriptCop" "Validating Cmdlet Metadata - $($testCmd.Name)" -Id $ProgressId -PercentComplete $perc
                if ($scriptCopError) {$scriptCopError = $null }
                $CmdletMetaData | 
                    Where-Object { 
                        $_.Cmdlet
                    } |
                    ForEach-Object { 
                        $commandInfo = $_.Cmdlet 
                        $null = $commandInfo | 
                            & $testCmd -ErrorAction SilentlyContinue -ErrorVariable ScriptCopError
                        
                        WriteScriptCopError                        
                    }                    
            }        
        }
            
        #endregion Validating Cmdlets        

        
        #region Validating Functions
        Write-Progress "Running ScriptCop" "Validating Functions" -Id $ProgressId  
                
        if ($currentRules.TestFunctionInfo) {
            $c = 0
            $ruleCount = @($currentRules.TestFunctionInfo).Count
            foreach ($testCmd in $currentRules.TestFunctionInfo){                        
                $c++
                $perc  = $c * 100 / $ruleCount
                Write-Progress "Running ScriptCop" "Validating Function Metadata - $($testCmd.Name)" -Id $ProgressId -PercentComplete $perc
                if ($scriptCopError) {$scriptCopError = $null }
                $CommandMetaData | 
                    Where-Object { 
                        $_.Function
                    } |
                    ForEach-Object { 
                        $commandInfo = $_.Function 
                        $null = $commandInfo | 
                            & $testCmd -ErrorAction SilentlyContinue -ErrorVariable ScriptCopError
                        
                        WriteScriptCopError                        
                    }  
            }        
        }
            
        #endregion Validating Functions
        
        #region Validating Applications
        Write-Progress "Running ScriptCop" "Validating Applications Metadata" -Id $ProgressId
                
        if ($currentRules.TestApplicationInfo) {
            $c = 0
            $ruleCount = @($currentRules.TestApplicationInfo).Count
            foreach ($testCmd in $currentRules.TestApplicationInfo){                        
                $c++
                $perc  = $c * 100 / $ruleCount
                Write-Progress "Running ScriptCop" "Validating Applications Metadata - $($testCmd.Name)" -Id $ProgressId -PercentComplete $perc
                if ($scriptCopError) {$scriptCopError = $null }
                $CommandMetaData | 
                    Where-Object { 
                        $_.Application
                    } |
                    ForEach-Object { 
                        $commandInfo = $_.Application 
                        $null = $commandInfo | 
                            & $testCmd -ErrorAction SilentlyContinue -ErrorVariable ScriptCopError
                        
                        WriteScriptCopError                        
                    }  
                    
                    
                
            }        
        }
                    
        #endregion Validating Applications
                    
        #region Validating Scripts
        Write-Progress "Running ScriptCop" "Validating Script Metadata" -Id $ProgressId
                
        if ($currentRules.TestScriptInfo) {
            $c = 0
            $ruleCount = @($currentRules.TestScriptInfo).Count
            foreach ($testCmd in $currentRules.TestScriptInfo){                        
                $c++
                $perc  = $c * 100 / $ruleCount
                Write-Progress "Running ScriptCop" "Validating Script Metadata - $($testCmd.Name)" -Id $ProgressId -PercentComplete $perc
                if ($scriptCopError) {$scriptCopError = $null }
                $CommandMetaData | 
                    Where-Object {  $_.Script } |
                    ForEach-Object { 
                        $commandInfo = $_.Script 
                        $null = $commandInfo | 
                            & $testCmd -ErrorAction SilentlyContinue -ErrorVariable ScriptCopError
                        
                        WriteScriptCopError                        
                    }                                    
            }        
        }
                   
        #endregion Validating Scripts    
        
        #region Validating Help
        Write-Progress "Running ScriptCop" "Validating Help" -Id $ProgressId
                
        if ($currentRules.TestHelpContent) {
            $c = 0
            $ruleCount = @($currentRules.TestHelpContent).Count
            foreach ($testCmd in $currentRules.TestHelpContent){                        
                $c++
                $perc  = $c * 100 / $ruleCount
                Write-Progress "Running ScriptCop" "Validating Help - $($testCmd.Name)" -Id $ProgressId -PercentComplete $perc
                if ($scriptCopError) {$scriptCopError = $null }
                $CommandMetaData | 
                    ForEach-Object {                    
                        $commandInfo = $_.Command
                        $null = & $testCmd -HelpCommand $_.Command -HelpContent $_.Help -ErrorAction SilentlyContinue -ErrorVariable ScriptCopError
                        WriteScriptCopError
                    }
                                        
            }        
        }
            
        #endregion Validating Help   
        
        #region Validating Tokens
        Write-Progress "Running ScriptCop" "Validating Tokens" -Id $ProgressId
                
        if ($currentRules.TestScriptToken) {
            $c = 0
            $ruleCount = @($currentRules.TestScriptToken).Count
            foreach ($testCmd in $currentRules.TestScriptToken){                        
                $c++
                $perc  = $c * 100 / $ruleCount                
                Write-Progress "Running ScriptCop" "Validating Tokens - $($testCmd.Name)" -Id $ProgressId -PercentComplete $perc
                if ($scriptCopError) {$scriptCopError = $null }
                $CommandMetaData | 
                    ForEach-Object {   
                        $commandInfo = $_.Command     
                        if ($_.Tokens -and $_.Text) {            
                            $null = & $testCmd -ScriptTokenCommand $_.Command -ScriptToken $_.Tokens -ScriptText "$($_.Text)" -ErrorAction SilentlyContinue -ErrorVariable ScriptCopError
                            WriteScriptCopError                        
                        }

                    }
                                        
            }        
        }
                    
        #endregion Validating Tokens   

    }
    
    
}
# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUYllsjix2gmOB9CFm5z2hzIMf
# pPKgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE0MDcxNzAwMDAwMFoXDTE1MDcy
# MjEyMDAwMFowaTELMAkGA1UEBhMCQ0ExCzAJBgNVBAgTAk9OMREwDwYDVQQHEwhI
# YW1pbHRvbjEcMBoGA1UEChMTRGF2aWQgV2F5bmUgSm9obnNvbjEcMBoGA1UEAxMT
# RGF2aWQgV2F5bmUgSm9obnNvbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAM3+T+61MoGxUHnoK0b2GgO17e0sW8ugwAH966Z1JIzQvXFa707SZvTJgmra
# ZsCn9fU+i9KhC0nUpA4hAv/b1MCeqGq1O0f3ffiwsxhTG3Z4J8mEl5eSdcRgeb+1
# jaKI3oHkbX+zxqOLSaRSQPn3XygMAfrcD/QI4vsx8o2lTUsPJEy2c0z57e1VzWlq
# KHqo18lVxDq/YF+fKCAJL57zjXSBPPmb/sNj8VgoxXS6EUAC5c3tb+CJfNP2U9vV
# oy5YeUP9bNwq2aXkW0+xZIipbJonZwN+bIsbgCC5eb2aqapBgJrgds8cw8WKiZvy
# Zx2qT7hy9HT+LUOI0l0K0w31dF8CAwEAAaOCAbswggG3MB8GA1UdIwQYMBaAFFrE
# uXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBTnMIKoGnZIswBx8nuJckJGsFDU
# lDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAw
# bjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1j
# cy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtY3MtZzEuY3JsMEIGA1UdIAQ7MDkwNwYJYIZIAYb9bAMBMCowKAYIKwYB
# BQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwgYQGCCsGAQUFBwEB
# BHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsG
# AQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEy
# QXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG
# 9w0BAQsFAAOCAQEAVlkBmOEKRw2O66aloy9tNoQNIWz3AduGBfnf9gvyRFvSuKm0
# Zq3A6lRej8FPxC5Kbwswxtl2L/pjyrlYzUs+XuYe9Ua9YMIdhbyjUol4Z46jhOrO
# TDl18txaoNpGE9JXo8SLZHibwz97H3+paRm16aygM5R3uQ0xSQ1NFqDJ53YRvOqT
# 60/tF9E8zNx4hOH1lw1CDPu0K3nL2PusLUVzCpwNunQzGoZfVtlnV2x4EgXyZ9G1
# x4odcYZwKpkWPKA4bWAG+Img5+dgGEOqoUHh4jm2IKijm1jz7BRcJUMAwa2Qcbc2
# ttQbSj/7xZXL470VG3WjLWNWkRaRQAkzOajhpTCCBTAwggQYoAMCAQICEAQJGBtf
# 1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEyMDAw
# MFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE620T1
# f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG+ykn
# x9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwgla4c
# SocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q16XTm
# K/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTFjg/B
# ougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOCAc0w
# ggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8E
# ejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZIAYb9
# bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BT
# MAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAfBgNV
# HSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOCAQEA
# PuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3sOH2
# 0ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsHDpEV
# +7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlxsQyP
# u6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy62ZD
# 2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQYhS6S
# kepobEQysmah5xikmmRR7zGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# MTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcg
# Q0ECEALqUCMY8xpTBaBPvax53DkwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFGp6cnqzrkwOg+2C
# z7WPv5dH5nR+MA0GCSqGSIb3DQEBAQUABIIBADSbuXKhfKYoEHuOqk+bGPc46xwA
# NsHFzmx/YqpyPpGIgC+HfIhmxjMfv3frcJCvgao2daVC2igKA98uDkHH5kUTtMZt
# YTU+iWt6Jnm0JxRw1af29XblMe1Efg2uCt3QfAAqMMYObua/PrbqVlz1HU8rqka9
# nExQv+2h8sYzL9V5RjqmpIMwP2CMtW3yFwVkFP00rMP6sBpdmjXpfddqPxXO77lD
# bx96NxeOlGrzinngj9UTGzCjWZNZq62UYrna+swcBSHZeklPnLB8Y83eDJu3lYU7
# KvtfVFVpwB0TGF2c2Wha2XDrQTfKQaNbbbnusEFY6VmOpva7n2IF+DbmNDM=
# SIG # End signature block
