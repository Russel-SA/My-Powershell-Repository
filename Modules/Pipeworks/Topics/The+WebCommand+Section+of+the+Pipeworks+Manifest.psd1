@{
    Name = 'The WebCommand Section of the Pipeworks Manifest'
    PSTypeName = 'http://shouldbeonschema.org/Topic'
    Content =  (ConvertFrom-Markdown @"
The most commonly used section in the Pipeworks Manifest is WebCommand.  WebCommand describes what commands in a module become web services, and the options that will be used when the command is converted into a web service.  WebCommand is a hashtable where the keys are the names of the command and the value is a table of parameters.  The example below is the WebCommand section from the module [ScriptCop](http://scriptcop.start-automating.com).
"@) + (
                Write-ScriptHTML @'
@{
    WebCommand = @{
        "Test-Command" = @{
            HideParameter = "Command"
            RunOnline=$true
        }
        "Get-ScriptCopRule" = @{
            RunWithoutInput = $true
            RunOnline=$true
        }
        "Get-ScriptCopPatrol" = @{
            RunWithoutInput = $true
            RunOnline=$true
        }
    }
}
'@)
                

}