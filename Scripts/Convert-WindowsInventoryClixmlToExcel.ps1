<#
	.SYNOPSIS
		Writes an Excel file containing the Database Engine information in a SQL Server Inventory file created by Get-WindowsInventoryToClixml.ps1.

	.DESCRIPTION
		This script loads a Windows Inventory file created by Get-WindowsInventoryToClixml.ps1 and calls the Export-WindowsInventoryToExcel function in the WindowsInventory module to write an Excel file containing the Windows Operating System information from the inventory.

		Microsoft Excel 2007 or higher must be installed in order to write the Excel file.
		
	.PARAMETER  FromPath
		The literal path to the XML file created by Get-WindowsInventoryToClixml.ps1.
		
	.PARAMETER  ToPath
		Specifies the literal path where the Excel file will be written. This path (but not the filename) must exist prior to executing this script.
		
		If not specified then ToPath defaults to the same directory specified by the FromPath paramter.
		
		Assuming the XML file specified in FromPath is named "Windows Inventory.xml" then the Excel file will be written to "Windows Inventory.xlsx"
		
	.PARAMETER  ColorTheme
		An Office Theme Color to apply to each worksheet. If not specified or if an unknown theme color is provided the default "Office" theme colors will be used.
		
		Office 2013 theme colors include: Aspect, Blue Green, Blue II, Blue Warm, Blue, Grayscale, Green Yellow, Green, Marquee, Median, Office, Office 2007 - 2010, Orange Red, Orange, Paper, Red Orange, Red Violet, Red, Slipstream, Violet II, Violet, Yellow Orange, Yellow
		
		Office 2010 theme colors include: Adjacency, Angles, Apex, Apothecary, Aspect, Austin, Black Tie, Civic, Clarity, Composite, Concourse, Couture, Elemental, Equity, Essential, Executive, Flow, Foundry, Grayscale, Grid, Hardcover, Horizon, Median, Metro, Module, Newsprint, Office, Opulent, Oriel, Origin, Paper, Perspective, Pushpin, Slipstream, Solstice, Technic, Thatch, Trek, Urban, Verve, Waveform

		Office 2007 theme colors include: Apex, Aspect, Civic, Concourse, Equity, Flow, Foundry, Grayscale, Median, Metro, Module, Office, Opulent, Oriel, Origin, Paper, Solstice, Technic, Trek, Urban, Verve
		
	.PARAMETER  ColorScheme
		The color theme to apply to each worksheet. Valid values are "Light", "Medium", and "Dark". 
		
		If not specified then "Medium" is used as the default value .

	.PARAMETER  LoggingPreference
		Specifies the logging verbosity to use when writing log entries.
		
		Valid values include: None, Standard, Verbose, and Debug.
		
		The default value is "None"
		
	.PARAMETER  LogPath
		A literal path to a log file to write details about what this script is doing. The filename does not need to exist prior to executing this script but the specified directory does.
		
		If a LoggingPreference other than None is specified and this parameter is not specified then the file is named "Windows Inventory - [Year][Month][Day][Hour][Minute].log" and is written to your "My Documents" folder.

		
	.EXAMPLE
		.\Convert-WindowsInventoryClixmlToExcel.ps1 -FromPath "C:\Inventory\Windows Inventory.xml" 
		
		Description
		-----------
		Writes an Excel file for the Windows Operating System information contained in "C:\Inventory\Windows Inventory.xml" to "C:\Inventory\Windows Inventory.xlsx".
		
		The Office color theme and Medium color scheme will be used by default.
		
	.EXAMPLE
		.\Convert-WindowsInventoryClixmlToExcel.ps1 -FromPath "C:\Inventory\Windows Inventory.xml"  -ColorTheme Blue -ColorScheme Dark
		
		Description
		-----------
		Writes an Excel file for the Windows Operating System information contained in "C:\Inventory\Windows Inventory.xml" to "C:\Inventory\Windows Inventory.xlsx".
		
		The Blue color theme and Dark color scheme will be used.

	
	.NOTES
		Blue and Green are nice looking Color Themes for Office 2013

		Waveform is a nice looking Color Theme for Office 2010

	.LINK
		Get-WindowsInventoryToClixml.ps1		

#>
[cmdletBinding(SupportsShouldProcess=$false)]
param(
	[Parameter(Mandatory=$true)] 
	[alias('from')]
	[ValidateNotNullOrEmpty()]
	[string]
	$FromPath
	,
	[Parameter(Mandatory=$false)] 
	[alias('to')]
	[ValidateNotNullOrEmpty()]
	[string]
	$ToPath = [System.IO.Path]::ChangeExtension($FromPath, '.xlsx')
	, 
	[Parameter(Mandatory=$false)] 
	[alias('loglevel')]
	[ValidateSet('none','standard','verbose','debug')]
	[string]
	$LoggingPreference = 'none'
	,
	[Parameter(Mandatory=$false)] 
	[alias('log')]
	[ValidateNotNullOrEmpty()]
	[string]
	$LogPath = (Join-Path -Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) -ChildPath ("Windows Inventory - " + (Get-Date -Format "yyyy-MM-dd-HH-mm") + ".log"))
	,
	[Parameter(Mandatory=$false)] 
	[alias('theme')]
	[string]
	$ColorTheme = 'office'
	,
	[Parameter(Mandatory=$false)] 
	[ValidateSet('dark','light','medium')]
	[string]
	$ColorScheme = 'medium' 
)


######################
# FUNCTIONS
######################

function Write-LogMessage {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[System.String]
		$Message
		,
		[Parameter(Position=1, Mandatory=$true)] 
		[alias('level')]
		[ValidateSet('information','verbose','debug','error','warning')]
		[System.String]
		$MessageLevel
	)
	try {
		if ((Test-Path -Path 'function:Write-Log') -eq $true) {
			Write-Log -Message $Message -MessageLevel $MessageLevel
		} else {
			Write-Host $Message
		}
	}
	catch {
		throw
	}
}


######################
# VARIABLES
######################
$ProgressId = Get-Random
$ProgressActivity = 'Convert-WindowsInventoryClixmlToExcel'
$ProgressStatus = $null

######################
# BEGIN SCRIPT
######################

# Import Modules that we need
Import-Module -Name LogHelper, WindowsInventory

# Set logging variables
Set-LogFile -Path $LogPath
Set-LoggingPreference -Preference $LoggingPreference

$ProgressStatus = "Starting Script: $($MyInvocation.MyCommand.Path)"
Write-LogMessage -Message $ProgressStatus -MessageLevel Information
Write-Progress -Activity $ProgressActivity -PercentComplete 0 -Status $ProgressStatus -Id $ProgressId

$ProgressStatus = "Loading inventory from '$FromPath'"
Write-LogMessage -Message $ProgressStatus -MessageLevel Information
Write-Progress -Activity $ProgressActivity -PercentComplete 0 -Status $ProgressStatus -Id $ProgressId

Import-Clixml -Path $FromPath | ForEach-Object {
	if ($_.ScanSuccessCount -gt 0) {
		$ProgressStatus = 'Writing Windows Inventory To Excel'
		Write-Progress -Activity $ProgressActivity -PercentComplete 50 -Status $ProgressStatus -Id $ProgressId
		Export-WindowsInventoryToExcel -WindowsInventory $_ -Path $ToPath -ColorTheme $ColorTheme -ColorScheme $ColorScheme
	} else {
		Write-LogMessage -Message 'No machines found!' -MessageLevel Warning
	}
}

$ProgressStatus = "End Script: $($MyInvocation.MyCommand.Path)"
Write-LogMessage -Message $ProgressStatus -MessageLevel Information
Write-Progress -Activity $ProgressActivity -PercentComplete 100 -Status $ProgressStatus -Id $ProgressId -Completed

# Remove Variables
Remove-Variable -Name ProgressId, ProgressActivity, ProgressStatus

# Remove Modules
Remove-Module -Name WindowsInventory, LogHelper

# Call garbage collector
[System.GC]::Collect()


# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUmpmiQlieda/afuMbk2nKVZUm
# SD6gggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFPnbROpdpGANm5gR
# lJB/QV3k9rB6MA0GCSqGSIb3DQEBAQUABIIBACkM/zYXVt/k+HG4JWhjy47sd8bi
# 8fjwT0lnOccEFdkUH70bHq4CLAkWd7bPR8JvSfzlSnx2szNb2GxtP1C3EPRsGnZY
# b3DqKrB6zG2mRGbCYfBk46zjcQTcsM0XIaqXdbbQ2DGW6Ex/l0H5O27Vv20bQkpt
# sUiQhN1b8hW5ZGCmapNMYXRoWygYszNA0aeLtCUskITfSls1lrsyHV1Ljlvs4C8/
# bk13pRSa1+grl9rbth+v09Q4hhXW6krVAFHWmVh5cT+jo/ppdvnlCXfo+QmL05Aa
# /u2vCzlLaTHkTh3Xc4thTCDnMwbK1zU9u44AEy/NDbE/mo5ph0zH8I5bnGg=
# SIG # End signature block
