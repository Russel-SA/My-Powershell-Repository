﻿function Request-CommandInput
{
    <#
    .Synopsis
        Generates a form to collect input for a command
    .Description
        Generates a form to collect input for a PowerShell command.  
                
        
        Get-WebInput is designed to handle the information submitted by the user in a form created with Request-CommandInput.
    .Link
        Get-WebInput
    .Example
        Request-CommandInput -CommandMetaData (Get-Command Get-Command) -DenyParameter ArgumentList
    #>
    [CmdletBinding(DefaultParameterSetName='ScriptBlock')]
    [OutputType([string])]
    param(
    # The metadata of the command.
    [Parameter(Mandatory=$true,ParameterSetName='Command',ValueFromPipeline=$true)]
    [Management.Automation.CommandMetaData]
    $CommandMetaData,
    
    # A script block containing a PowerShell function.  Any code outside of the Powershell function will be ignored.
    [Parameter(Mandatory=$true,ParameterSetName='ScriptBlock')]
    [ScriptBlock]
    $ScriptBlock,
    
    # The name of the parameter set to request input
    [string]
    $ParameterSet,    
    
    # Explicitly allowed parameters (by default, all are allowed unless they are explictly denied)
    [string[]]
    $AllowedParameter,
    
    # Explicitly denied parameters.
    [Alias('HideParameter')]
    [string[]]
    $DenyParameter,
    
    # The text on the request button
    [string]
    $ButtonText,

    # The url to a button image button
    [string]
    $ButtonImage,

    # If set, does not display a button 
    [switch]
    $NoButton,
    
    # The order of items
    [string[]]
    $Order,
        
    # The web method the form will use
    [ValidateSet('POST','GET')]
    [string]
    $Method = "POST",

    # The css margin property to use for the form
    [string]
    $Margin = "1%",
    
    # The action of the form
    [string]
    $Action,
        
    # The platform the created input form will work.  
    # This is used to created an XML based layout for any device
    [ValidateSet('Web', 'Android', 'AndroidBackend', 'CSharpBackEnd', 'iOS', 'WindowsMobile', 'WindowsMetro', 'Win8', 'WPF', 'GoogleGadget', 'TwilML', 'PipeworksDirective')]
    [string]
    $Platform = 'Web',

    # If set, uses a Two column layout
    [Switch]
    $TwoColumn,

    # If set, will load the inner control with ajax
    [Switch]
    $Ajax
    )
    
    begin {       
        $allPipeworksDirectives = @{}
        $firstcomboBox = $null          
        Add-Type -AssemblyName System.Web 
        function ConvertFrom-CamelCase
        {
            param([string]$text)
            
            $r = New-Object Text.RegularExpressions.Regex "[a-z][A-Z]", "Multiline"
            $matches = @($r.Matches($text))
            $offset = 0
            foreach ($m in $matches) {
                $text = $text.Insert($m.Index + $offset + 1," ")
                $offset++
            }
            $text
        }

       
             
        
        
        function New-TextInput($defaultNumberOfLines, [switch]$IsNumber, [string]$CssClass,[string]$type) {
            $linesForInput = if ($pipeworksDirectives.LinesForInput -as [Uint32]) {
                $pipeworksDirectives.LinesForInput -as [Uint32]
            } else {
                $defaultNumberOfLines
            }
            
            $columnsForInput = 
                if ($pipeworksDirectives.ColumnsForInput -as [Uint32]) {
                    $pipeworksDirectives.ColumnsForInput -as [Uint32]
                } else {
                    if ($Request -and $Request['Snug']) {
                        30
                    } else {
                        60
                    }
                    
                }
            
            
            if ($Platform -eq 'Web') {
                if ($pipeworksDirectives.ContentEditable) {
                    "<div id='${ParameterIdentifier}_Editable' style='width:90%;padding:10px;margin:3px;min-height:5%;border:1px solid' contenteditable='true' designMode='on'>$(if ($pipeworksDirectives.Default) { "<i>" + $pipeworksDirectives.Default + "</i>" })</div>
                    
                    
                    <input type='button' id='${inputFieldName}saveButton' value='Save' onclick='save${inputFieldName};' />
                    <input type='button' id='${inputFieldName}clearButton' value='Clear' onclick='clear${inputFieldName};' />
                    <input type='hidden' id='$parameterIdentifier' name='$inputFieldName' />
                    <script>                        
                        `$(function() {
                            `$( `"#$($inputFieldName)saveButton`" ).button().click(
                                function(event) { 
                                    document.getElementById(`"${ParameterIdentifier}`").value = document.getElementById(`"${ParameterIdentifier}_Editable`").innerHTML;        
                                });
                                
                            `$( `"#$($inputFieldName)clearButton`" ).button().click(
                                function(event) {
                                    document.getElementById(`"${ParameterIdentifier}`").value = '';
                                    document.getElementById(`"${ParameterIdentifier}_Editable`").innerHTML = '';
                                });                        
                        })
                    </script>
                    "

                } else {

                    if ($LinesForInput -ne 1) {
                        "<textarea style='width:100%;' $(if ($cssClass) { "class='$cssClass'"}) $(if($type) { "type='$type'" }) name='$inputFieldName' rows='$LinesForInput' cols='$ColumnsForInput'>$($pipeworksDirectives.Default)</textarea>"
                    } else {
                        "<input style='width:100%' $(if ($cssClass) { "class='$cssClass'"}) $(if($type) { "type='$type'" }) name='$inputFieldName' $(if ($isnumber) {'type=''number'''}) $(if ([Double], [float] -contains $parameterType) {'step=''0.01'''}) value='$($pipeworksDirectives.Default)' />"
                    }
                
                    if ($cssClass -eq 'dateTimeField') {
                        "<script>
                        `$(function() {
                            `$( `".dateTimeField`" ).datepicker({
                			    showButtonPanel : true,
                                changeMonth: true,
                                changeYear: true,
                                showOtherMonths: true,
                                selectOtherMonths: true
                		    });
                        })
                        </script>"
                    }
                }
            } elseif ($Platform -eq 'Android') {
                @"
<EditText
    android:id="@+id/$parameterIdentifier"
    $theDefaultAttributesInAndroidLayout    
    android:minLines='${LinesForInput}'
    $(if ($isnumber) {'type=''number'''})
    $(if ($defaultValue) { "android:text='$defaultValue'" } )/>
                
"@                            
            } elseif ($Platform -eq 'AndroidBackEnd') {                
                $extractTextFromEditTextAndUseForQueryString 
            } elseif ($Platform -eq 'CSharpBackEnd') {
                $extractTextFromTextBoxAndUseForQueryString
            } elseif ('WindowsMobile', 'WPF' ,'Metro', 'SilverLight', 'Win8' -contains $platform) {
                if ($DefaultNumberOfLines -eq 1) { 
                        @"
<TextBox
    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
    Margin="7, 5, 7, 5"
    x:Name="$parameterIdentifier"    
    $(if ($defaultValue) { "Text='$defaultValue'" })    
    Tag='Type:$($parameterType.Fullname)' />
"@        
                } else {
                        @"
<TextBox
    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
    Margin="7, 5, 7, 5"
    x:Name="$parameterIdentifier"    
    $(if ($defaultValue) { "Text='$defaultValue'" })    
    Tag='Type:$($parameterType.Fullname)'
    AcceptsReturn='true'    
    MinLines='${DefaultNumberOfLines}' />
"@        
                     
                } 
            } elseif ('GoogleGadget' -eq $platform) {
@"
<UserPref name="$parameterIdentifier" display_name="$friendlyParameterName" default_value="$($pipeworksDirectives.Default)"/>            
"@
            } elseif ('TwilML' -eq $Platform) {
                if ($IsNumber) {
@"
<Gather finishOnKey="*" $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" })>
    <Say>$([Security.SecurityElement]::Escape($parameterHelp)).  Press * when you are done.</Say>
</Gather>
"@
                } elseif ($friendlyParameterName -like "Record*" -or $friendlyParameterName -like "*Recording") {
@"
<Say>$([Security.SecurityElement]::Escape($parameterHelp))</Say>
<Record $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" })>
    
</Record>
"@            

                } elseif ($friendlyParameterName -like "Transcribe*" -or $friendlyParameterName -like "*Transcription") {
@"
<Say>$([Security.SecurityElement]::Escape($parameterHelp))</Say>
<Record $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" }) transcribe='true' />
"@                        
                
                } elseif ($pipeworksDirectives.RecordInput -or $pipeworksDirectives.Record -or $pipeworksDirectives.Recording) {
@"
<Say>$([Security.SecurityElement]::Escape($parameterHelp))</Say>
<Record $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" }) />
"@            

                } else {
@"
<Say>$([Security.SecurityElement]::Escape($parameterHelp))</Say>
<Record $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" }) transcribe='true' />
"@            
                
                }
            }
        } 

        # Some chunks of code are reused so often, they need to be variables
        $extractTextFromEditTextAndUseForQueryString = @"
    try {     
        // Cast the item to an EditText control
        EditText text = (EditText)foundView;
        		
        // Extract out the value
		String textValue = text.getText().toString();
        
        // If it is set...
		if (textValue != null && textValue.getLength() > 0) {
            // Append the & to separate parameters
    		if (! initializedQueryString) {
    			initializedQueryString = true;        			
    		} else {
    			queryString.append("&");
    		}
                		    		
    		queryString.append(textFieldID);
            queryString.append("=");
    		queryString.append(URLEncoder.encode(textValue));        			
		}   
    } catch (Exception e) {
        e.printStackTrace();
    }

"@   

        $extractTextFromTextBoxAndUseForQueryString = @"
    try {
        // Cast the item to an TextBox control
        TextBox text = (TextBox)foundView;
        		
        // Extract out the value
		String textValue = text.Text;
        
        // If it is set...
		if (! String.IsNullOrEmpty(textValue)) {
            // Append the & to separate parameters
    		if (! initializedQueryString) {
    			initializedQueryString = true;        			
    		} else {
    			queryString.Append("&");
    		}
                		    		
    		queryString.Append(textFieldID);
            queryString.Append("=");
    		queryString.Append(HttpUtility.UrlEncode(textValue));        			
		}   
    } catch (Exception ex) {
        throw ex;
    }

"@        

        # Most android UI requires these two lines
        $theDefaultAttributesInAndroidLayout = @"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
"@        
    }
    
    process { 
    
        # The ScriptBlock parameter set will just take the first command declared within a scriptblock
        if ($psCmdlet.ParameterSetName -eq 'ScriptBlock') {
            $func = Get-FunctionFromScript -ScriptBlock $ScriptBlock | Select-Object -First 1 
            . ([ScriptBlock]::Create($func))
            $matched = $func -match "function ((\w+-\w+)|(\w+))"
            if ($matched -and $matches[1]) {
                $command=Get-Command $matches[1]
            }
            $CommandMetaData = [Management.Automation.CommandMetaData]$command                        
        }
               
        $inputForm =  New-Object Text.StringBuilder 
        $idSafeCommandName = $commandMetaData.Name.Replace('-','')
        
        # Extract out help
        $help = Get-Help -Name $CommandMetaData.Name
        $richHelpExists = $false
        if ($help -isnot [string]) {
            $richHelpExists = $true
        }
        
        if (-not $buttonText) {
            $ButtonText = ConvertFrom-CamelCase $commandMetaData.Name.Replace('-', ' ')        
        }

        #region Start of Form
        if ($platform -eq 'Web') {
            $RandomSalt = Get-Random
            $cssBaseName = "$($commandMetaData.Name)_Input"
            # If the platform is web, it's a <form> input        
            $null = $inputForm.Append("
<div class='$($commandMetadata.Name)_InlineOutputContainer' id='$($commandMetaData.Name)_InlineOutputContainer_$RandomSalt' style='margin-top:3%;margin-bottom:3%' >
</div>
<form method='$method' $(if ($action) {'action=`"' + $action + '`"' }) class='$($commandMetaData.Name)_Input' id='$($commandMetaData.Name)_Input_$RandomSalt' enctype='multipart/form-data'>
    <div style='border:0px'>
    <style>
    textarea:focus, input:focus {
        border: 2px solid #009;
    }
    </style>")
        } elseif ($Platform -eq 'Android') {
            
            # If the platform is Android, it's a ViewSwitcher containing a ScrollView containing a LinearLayout
            $null = $inputForm.Append(@"
<ViewSwitcher xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/$($idSafeCommandName + '_Switcher')"
    $theDefaultAttributesInAndroidLayout >
    <ScrollView 
        android:id="@+id/$($idSafeCommandName + '_ScrollView')"
        $theDefaultAttributesInAndroidLayout>
        <LinearLayout 
            $theDefaultAttributesInAndroidLayout
            android:orientation="vertical" >
    
"@)            
        } elseif ($Platform -eq 'AndroidBackEnd') {
            # In an android back end, create a class contain a static method to collect the parameters
            $null = $inputForm.Append(@"
    public String Get${IdSafeCommandName}QueryString() {
        // Save getResources() and getPackageName() so that each lookup is slightly quicker
        Resources allResources = getResources();
        String packageName = getPackageName();  
        StringBuilder queryString = new StringBuilder();                   
        Boolean initializedQueryString = false;
        Object foundView;
        String textFieldID;
"@)         
        } elseif ($Platform -eq 'CSharpBackEnd') {
            # In an android back end, create a class contain a static method to collect the parameters
            $null = $inputForm.Append(@"
    public String Get${IdSafeCommandName}QueryString() {
        // Save getResources() and getPackageName() so that each lookup is slightly quicker
        StringBuilder queryString = new StringBuilder();                   
        bool initializedQueryString = false;
        Object foundView;
        String textFieldID;
"@)         
        } elseif ('WPF', 'WindowsMobile', 'WindowsMetro', 'Win8' -contains $Platform) {
            # On WPF, WindowsMobile, or WindowsMetro it's a Grid containing a ScrollView and a StackPanel
            $null = $inputForm.Append(@"
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <ScrollViewer>
        <StackPanel>    
"@)         
        } elseif ('GoogleGadget' -eq $platform) {
            $null = $inputForm.Append(@"        
<Module>
  <ModulePrefs title="$ButtonText" height="400"/> 
"@)        
        } elseif ('TwilML' -eq $platform) {
            $null = $inputForm.Append(@"        
<Response> 
"@)        
        }
        
        #endregion Start of Form
            
            
        #region Filter Parameters
        # Without an explicit whitelist, get all parameters    
   
        if (-not $AllowedParameter) {
            $allowedParameter  = $CommandMetaData.Parameters.Keys 
        }
   
        # If a parameter set was provided, filter out parameters from other parameter sets
        if ($parameterSet) {        
            $allParameters = $allowedParameter |
                Where-Object {
                    $commandMetaData.Parameters[$_].Attributes | 
                        Where-Object { $_.ParameterSetName -eq $parameterSet }
                }
        }
        
        # Remove the denied parameters    
        $allParameters = foreach ($param in $allowedParameter) {
            if ($DenyParameter -notcontains $param) {
                $param
            }
        }
        
        # Order parameters if they are not explicitly ordered
        if (-not $order) {
            $order = 
                 $allParameters | 
                    Select-Object @{
                        Name = "Name"
                        Expression = { $_ }
                    },@{
                        Name= "NaturalPosition"
                        Expression = { 
                            $p = @($commandMetaData.Parameters[$_].ParameterSets.Values)[0].Position
                            if ($p -ge 0) {
                                $p
                            } else { 1gb }                                              
                        }
                    } | 
                    Sort-Object NaturalPosition| 
                    Select-Object -ExpandProperty Name
        }
        #endregion Filter Parameters                
        $mandatoryFields = @()
                                
        foreach ($parameter in $order) {
            if (-not $parameter) { continue }
            if (-not ($commandMetaData.Parameters[$parameter])) { continue }
            $parameterType = $commandMetaData.Parameters[$parameter].ParameterType
            $IsMandatory = foreach ($pset in $CommandMetaData.Parameters[$parameter].ParameterSets.Values) {
                if ($pset.IsMandatory) { $true; break} 
            }
            $friendlyParameterName = ConvertFrom-CamelCase $parameter
            $inputFieldName = "$($CommandMetaData.Name)_$parameter"                
            $parameterIdentifier = "${idSafeCommandName}_${parameter}"

            if ($IsMandatory) {
                $mandatoryFields += $parameterIdentifier
            }
            if ($Platform -eq 'Web') { 
                $boldIfMandatory = if ($IsMandatory) { "<b>" } else { "" } 
                $unboldIfMandatory = if ($IsMandatory) { "</b>" } else { "" } 
                if (-not $TwoColumn) {
                    $null = $inputForm.Append("
        <div style='margin-top:2%;margin-bottom:2%;'>
        <div style='width:37%;float:left;'>        
        <label for='$inputFieldName' style='text-align:left;font-size:1.3em'>
        ${boldIfMandatory}${friendlyParameterName}${unboldIfMandatory}
        </label>
        ")
                    ""
                } else {
                    $null = $inputForm.Append("
    <tr>
        <td style='width:25%'><p>${boldIfMandatory}${friendlyParameterName}${unboldIfMandatory}</p></td>
        <td style='width:75%;text-align:center;margin-left:15px;padding:15px;font-size:medium'>")
                }
            } elseif ($platform -eq 'Android') {
            # Display parameter name, unless it's a checkbox (then the parameter name is inline)
                if ([Switch], [Bool] -notcontains $parameterType) {
                
                    $null = $inputForm.Append(@"
    <TextView
        $theDefaultAttributesInAndroidLayout
        android:text="$friendlyParameterName"        
        android:padding="5px"    
        android:textAppearance="?android:attr/textAppearanceMedium"    
        android:textStyle='bold' />

"@)
                }
            } elseif ($platform -eq 'AndroidBackend') {
                
                # If it's android backend, simply add a lookup for the values to the method
                $null = $inputForm.Append(@"

    String textFieldID = "$parameterIdentifier";
    View foundView = findViewById(
        allResources.
        getIdentifier(textFieldID,         
	       "id", 
		  packageName));

"@)                        
            } elseif ($platform -eq 'CSharpBackend') {
                
                # If it's android backend, simply add a lookup for the values to the method
                $null = $inputForm.Append(@"

    textFieldID = "$parameterIdentifier";
    foundView = this.FindName(textFieldID);

"@)                        
            } elseif ($platform -eq 'WindowsMobile' -or 
                $platform -eq 'WPF' -or
                $platform -eq 'Metro' -or 
                $Platform -eq 'Win8') {
            
                $MajorStyleChunk = if ($Platform -ne 'WindowsMobile') {
                    "FontSize='19'"
                } else {
                    "Style='{StaticResource PhoneTextExtraLargeStyle}'"
                }
                $includeHelp = if ([Switch], [Bool] -notcontains $parameterType) {
                    "
                    <TextBlock           
                        $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
                        $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })         
                        $MajorStyleChunk 
                        Margin='28 2 0 3'
                        FontWeight='Bold'
                        Text='$FriendlyParameterName' />                    
                    "            
                    } else { 
                        "" 
                    }
            $null = $inputForm.Append(@"
                $includeHelp
"@)
            }
        
            $StyleChunk = if ($Platform -ne 'WindowsMobile') {
                "FontSize='14'"
            } else {
                "Style='{StaticResource PhoneTextSubtleStyle}'"
            }
            
            $attributes = $commandMetaData.Parameters[$parameter].attributes
            $parameterHelp  = 
                foreach ($p in $help.Parameters.Parameter) {
                    if ($p.Name -eq $parameter) {
                        $p.Description | Select-Object -ExpandProperty Text
                    }
                }                
            
                
            $parameterVisibleHelp = $parameterHelp -split ("[`n`r]") |? { $_ -notlike "|*" } 
            
            $pipeworksDirectives  = @{}
            foreach ($line in $parameterHelp -split ("[`n`r]")) {
                if ($line -like "|*") {
                    $directiveEnd= $line.IndexofAny(": `n`r".ToCharArray())
                    if ($directiveEnd -ne -1) {
                        $name, $rest = $line.Substring(1, $directiveEnd -1).Trim(), $line.Substring($directiveEnd +1).Trim()
                        $pipeworksDirectives.$Name = $rest
                    } else {
                        $name = $line.Substring(1).Trim()
                        $pipeworksDirectives.$Name = $true
                    }
                    
                    
                }
            }
                                         
                
            $parameterHelp= $parameterVisibleHelp -join ([Environment]::NewLine)
            if ($parameterHelp) {
                if ($Platform -eq 'Web') {
                    $null = $inputForm.Append("<br style='line-height:150%' />$(
ConvertFrom-Markdown -md $parameterHelp)")            
                } elseif ($Platform -eq 'Android') {
                    if ([Switch], [Bool] -notcontains $parameterType) {
                        $null = $inputForm.Append("
                        <TextView
                            $theDefaultAttributesInAndroidLayout
                            android:text=`"$([Web.HttpUtility]::HtmlAttributeEncode($parameterHelp))`"       
                            android:padding='2px'    
                            android:textAppearance='?android:attr/textAppearanceSmall' />")
                    }
                } elseif ('WindowsMobile', 'WPF' ,'Metro', 'SilverLight', 'Win8' -contains $platform) {
                    if ([Switch], [Bool] -notcontains $parameterType) {
                        $null = $inputForm.Append("
                <TextBlock
                    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
                    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
                    Name='${parameter}_Description_TextBlock'
                    $StyleChunk
                    Margin='7,0, 5,0'
                    TextWrapping='Wrap'>
                    $([Security.SecurityElement]::Escape($parameterHelp))
                </TextBlock>")
                    }
                }
            }
            
            if ($platform -eq 'Web') {
                $null = $inputForm.Append("</div>
                <div style='float:right;width:60%;'>
                
                ")
            
            }



            $validateSet = 
                foreach ($attribute in $commandMetaData.Parameters[$parameter].Attributes) {
                    if ($attribute.TypeId -eq [Management.Automation.ValidateSetAttribute]) {
                        $attribute
                        break
                    }
                }                
            
            $defaultValue = $pipeworksDirectives.Default
            if ($pipeworksDirectives.Options -or $validateSet -or $parameterType.IsSubClassOf([Enum])) {
                $optionList = 
                    if ($pipeworksDirectives.Options) {
                        Invoke-Expression -Command "$($pipeworksDirectives.Options)" -ErrorAction SilentlyContinue
                    } elseif ($ValidateSet) {
                        $ValidateSet.ValidValues
                    } elseif ($parameterType.IsSubClassOf([Enum])) {                        [Enum]::GetValues($parameterType)
                    }            
            
                if ($Platform -eq 'Web') {
                        $options = foreach ($option in $optionList) {
                            $selected = if ($defaultValue -eq $option) {
                                " selected='selected'"
                            } else {
                                ""
                            }
                            "$(' ' * 20)<option $selected>$option</option>"
                        }
                        $options = $options -join ([Environment]::NewLine)
                        if (-not $firstcomboBox) {
                            $firstcomboBox = $optionList
                            
                        }      
                        $null = $inputForm.Append("<select class='comboboxfield' name='$inputFieldName' value='$($pipeworksDirectives.Default)'>                            
                            $(if (-not $IsMandatory) { "<option> </option>" })
                            $options
                        </select>
                        ")
                } elseif ($Platform -eq 'Android') {
                    # Android is a bit of a pita.  There are two nice controls for this: Spinner and AutoCompleteEditText, but both
                    # cannot specify the resources in the same XML file as the control.
                    
                    if ($optionList.Count -gt 10) {
                        # Text box
                        $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 1)")                                        
                    } else {
                                                            
                        $null = $inputForm.Append(@"                        
    <RadioGroup
        android:id="@+id/$($idSafeCommandName + '_' + $parameter)"
        $theDefaultAttributesInAndroidLayout>
"@)        
                        foreach ($value in $optionList) { 
                            
                            $null = $inputForm.Append("
        <RadioButton                        
            $theDefaultAttributesInAndroidLayout
            android:text='$value' />")                                            
                            
                        } 
                        
                        $null = $inputForm.Append(@"                        
    </RadioGroup>
"@)                
                    }
                } elseif ('TwilML' -eq $platform) {                                               
                    # Twilio           
                    $friendlyParameterName = ConvertFrom-CamelCase $parameter

                    $optionNumber = 1
                    $phoneFriendlyHelp = 
                        foreach ($option in $optionList) {
                            "Press $OptionNumber for $Option"
                            $optionNumber++
                        } 
                    $phoneFriendlyHelp  = $phoneFriendlyHelp -join ".  $([Environment]::NewLine)"                    
                    
                    $null = $inputForm.Append(@"
    <Gather numDigits="$($optionNumber.ToString().Length)" $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" })>     
        <Say>
            $([Security.SecurityElement]::Escape($phoneFriendlyHelp ))
        </Say>        
    </Gather>
"@)                 
                
                } elseif ('WindowsMobile', 'WPF' ,'Metro', 'SilverLight', 'Win8' -contains $platform) {
                    # XAML does not have this limitation
                    if ($optionList.Count -lt 5) {
                        # Radio Box
                        # Combo Box                         
                        $null = $inputForm.Append("
<Border x:Name='$($idSafeCommandName + '_' + $parameter)'>
    <StackPanel>")                                            
                      

                        foreach ($value in $optionList) { 
                            
                            $null = $inputForm.Append("
    <RadioButton 
        $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
        $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
        GroupName='$($idSafeCommandName + '_' + $parameter)'>$([Security.SecurityElement]::Escape($value))</RadioButton>")                                            
                            
                        } 
                        $null = $inputForm.Append("
    </StackPanel>
</Border>")                                            
                            
                        
                    } else {
                        # Combo Box                         
                        $null = $inputForm.Append(@"                        
    <ComboBox         
        x:Name='$($idSafeCommandName + '_' + $parameter)'
        $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
        $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" }) >
"@)        
                        foreach ($value in $optionList) { 
                            
                            $null = $inputForm.Append("
        <ComboBoxItem>$([Security.SecurityElement]::Escape($value))</ComboBoxItem>")                                            
                            
                        } 
                        
                        $null = $inputForm.Append(@"                        
    </ComboBox>
"@)                
                    }
                } elseif ('GoogleGadget' -eq $platform ) {
                    $enumItems  = foreach ($option in $optionList) {
                        "<EnumValue value='$option'/>"
                    }
                    $null = $inputForm.Append( @"
<UserPref name="$parameterIdentifier" display_name="$FriendlyParameterName" datatype="enum" >
    $enumItems 
</UserPref> 
"@)                    
                }                                                    
            } elseif ([int[]], [uint32[]], [double[]], [int], [uint32], 
                [double], [Timespan], [Uri], [DateTime], [type], [version] -contains $parameterType) {
                # Numbers and similar primitive types become simple input boxes.  When possible, use one of the new
                # HTML5 input types to leverage browser support.        
                if ([int[]], [uint32[]], [double[]], [int], [uint32], [double] -contains $parameterType) {
                    $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 1 -IsNumber)")
                } elseif ($parameterType -eq [DateTime]) {
                    # Add A JQueryUI DatePicker
                    $addDatePicker = $true
                    $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 1 -IsNumber -CssClass 'dateTimeField' -type text)")
                } else {
                    $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 1)")                                        
                }
            } elseif ($parameterType -eq [byte[]]) {
                if ($platform -eq 'Web') {
                    if ($pipeworksDirectives.File) {
    $null = $inputForm.Append("<input type='file' name='$inputFieldName' chars='40' style='width:100%' $(if ($pipeworksDirectives.Accept) {"accept='$($pipeworksDirectives.Accept)"})'>")                                        
                    } elseif ($pipeworksDirectives.FilePickerIO) {
    $null = $inputForm.Append("<input type='filepicker' data-fp-apikey='$($pipeworksManifest.FilePickerIOKey)' name='$InputFieldName' $(if ($pipeworksDirectives.Accept) {"data-fp-mimetype='$($pipeworksDirectives.Accept)"})' />")
                    }
                }
            } elseif ($parameterType -eq [Security.SecureString]) {
                if ($platform -eq 'Web') {
    $null = $inputForm.Append("<input type='password' name='$inputFieldName' style='width:100%'>")                                        
                } 
            } elseif ($parameterType -eq [string]) {            
                if ($pipeworksDirectives.Color -and $Platform -eq 'Web') {
                    # Show a JQueryUI Color Picker
$colorInput = @"
<style>
    #red_$parameterIdentifier, #green_$parameterIdentifier, #blue_$parameterIdentifier {
        float: left;
        clear: left;
        width: 300px;
        margin: 15px;
    }
    #swatch_$parameterIdentifier {
        width: 120px;
        height: 100px;
        margin-top: 18px;
        margin-left: 350px;
        background-image: none;
    }
    #red_$parameterIdentifier .ui-slider-range { background: #ef2929; }
    #red_$parameterIdentifier .ui-slider-handle { border-color: #ef2929; }
    #green_$parameterIdentifier .ui-slider-range { background: #8ae234; }
    #green_$parameterIdentifier .ui-slider-handle { border-color: #8ae234; }
    #blue_$parameterIdentifier .ui-slider-range { background: #729fcf; }
    #blue_$parameterIdentifier .ui-slider-handle { border-color: #729fcf; }
    </style>
    <script>
    function hexFromRGB(r, g, b) {
        var hex = [
            r.toString( 16 ),
            g.toString( 16 ),
            b.toString( 16 )
        ];
        `$.each( hex, function( nr, val ) {
            if ( val.length === 1 ) {
                hex[ nr ] = "0" + val;
            }
        });
        return hex.join( "" ).toUpperCase();
    }
    function refresh${ParameterIdentifier}Swatch() {
        var red = `$( "#red_$parameterIdentifier" ).slider( "value" ),
            green = `$( "#green_$parameterIdentifier " ).slider( "value" ),
            blue = `$( "#blue_$parameterIdentifier" ).slider( "value" ),
            hex = hexFromRGB( red, green, blue );
        `$( "#swatch_$parameterIdentifier" ).css( "background-color", "#" + hex );
        `$('#$parameterIdentifier').val(hex)
    }
    `$(function() {
        `$( "#red_$parameterIdentifier, #green_$parameterIdentifier, #blue_$parameterIdentifier " ).slider({
            orientation: "horizontal",
            range: "min",
            max: 255,
            value: 127,
            slide: refresh${ParameterIdentifier}Swatch,
            change: refresh${ParameterIdentifier}Swatch
        });
        `$( "#red_$parameterIdentifier" ).slider( "value", 255 );
        `$( "#green_$parameterIdentifier " ).slider( "value", 140 );
        `$( "#blue_$parameterIdentifier " ).slider( "value", 60 );
    });
</script>
<div id="red_$parameterIdentifier"></div>
<div id="green_$parameterIdentifier"></div>
<div id="blue_$parameterIdentifier"></div>
 
<div id="swatch_$parameterIdentifier" class="ui-widget-content ui-corner-all"></div>
<input name='$inputFieldName' id='$parameterIdentifier' type='text' value='' style='width:120px;margin-top:18px;margin-left: 350px;'>
"@
                    $null = $inputForm.Append($colorInput)                                                                                                                             
                } else {
                    $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 1)")                                                                                                                             
                }                                  
                
            } elseif ([string[]], [uri[]] -contains $parameterType) {                             
                $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 4)")                                                                
            } elseif ([ScriptBlock] -eq $parameterType) {                             
                $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 6)")                                                                
            } elseif ([Hashtable] -eq $parameterType) {                             
                $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 6)")                                                                
            } elseif ([switch], [bool] -contains $parameterType) {
                if ($platform -eq 'Web') {
                    $null = $inputForm.Append("<input name='$inputFieldName' type='checkbox' />")
                } elseif ($platform -eq 'Android') {
                    $null = $inputForm.Append(@"
            <CheckBox
                android:id="@+id/$($commandMetaData.Name.Replace("-", "") + "_" + $parameter)"
                $theDefaultAttributesInAndroidLayout        
                android:text="$friendlyParameterName"
                android:textAppearance="?android:attr/textAppearanceMedium"    
                android:textStyle='bold' />  
                                 
            <TextView
                $theDefaultAttributesInAndroidLayout        
                android:text="$([Web.HttpUtility]::HtmlAttributeEncode($parameterHelp))"        
                android:padding="2px"    
                android:textAppearance="?android:attr/textAppearanceSmall" />
"@)          
                } elseif ('WindowsMobile', 'WPF' ,'Metro', 'SilverLight', 'Win8' -contains $platform) {
                    $null = $inputForm.Append(@"
            <CheckBox
                Margin="5, 5, 2, 0"
                $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
                $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
                x:Name='$($idSafeCommandName + '_' + $parameter)'>
                <StackPanel Margin="3,-5,0,0">
                <TextBlock
                    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
                    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
                    Name='${parameter}_ParameterName_TextBlock'
                    $MajorStyleChunk 
                    FontWeight='Bold'
                    Text='$friendlyParameterName' />   
                    
                <TextBlock
                    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
                    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
                    Name='${parameter}_Description_TextBlock'
                    $StyleChunk    
                    TextWrapping='Wrap'>                            
                    $([Security.SecurityElement]::Escape($parameterHelp))
                </TextBlock>
                </StackPanel>
            </CheckBox>           
"@)        
                }  elseif ($platform -eq 'AndroidBackEnd') {
                    $null = $inputForm.Append(@"
        try {
            CheckBox checkbox = (CheckBox)foundView;
    		
    		if (! initializedQueryString) {
    			initializedQueryString = true;        			
    		} else {
    			queryString.append("&");
    		}

            queryString.append(textFieldID);
            queryString.append("=");
            
            
            if (checkbox.isChecked()) {
    			queryString.append("true");
    		} else {
    			queryString.append("false");
    		}				
        } catch (Exception e) {
            e.printStackTrace();
        }
"@)                                    
                }  elseif ($platform -eq 'CSharpBackEnd') {
                    $null = $inputForm.Append(@"
            try {
                CheckBox checkbox = (CheckBox)foundView;
        		
        		if (! initializedQueryString) {
        			initializedQueryString = true;        			
        		} else {
        			queryString.Append("&");
        		}
                
                queryString.Append(textFieldID);
                queryString.Append("=");
                
                if ((bool)(checkbox.IsChecked)) {
        			queryString.Append("true");
        		} else {
        			queryString.Append("false");
        		}	
            } catch (Exception ex){
                throw ex;
            }			
        
"@)                                    
                } elseif ($Platform -eq 'TwilML') {
                    # Twilio           
                    $friendlyParameterName = ConvertFrom-CamelCase $parameter
                    $phoneFriendlyHelp = "$(if ($parameterHelp) { "$ParameterHelp "} else { "Is $FriendlyParameterName" })   If so, press 1.  If not, press 0."  
                    
                    $null = $inputForm.Append(@"
    <Gather numDigits="1" $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" }) >     
        <Say>
        $([Security.SecurityElement]::Escape($phoneFriendlyHelp ))
        </Say>        
    </Gather>
"@)                 
                }
            }                                                    
         
            
        # Close the parameter input 
        if ($platform -eq 'Web') {
                
                $null = $inputForm.Append("
        </div>
        <div style='clear:both'>
        </div>
        </div>

        ")
        } elseif ('WindowsMobile', 'Metro', 'WPF', 'Win8' -contains $platform) {
                $null = $inputForm.Append("
")
                
        
                 
        } elseif ('PipeworksDirective' -eq $platform ) {
            if ($pipeworksDirectives.Count) {
                $allPipeworksDirectives.$parameter = $pipeworksDirectives
            }
            
        }       
    }
    

    #region Button
    if (-not $NoButton) { 
        if ($Platform -eq 'Web') {

            $checkForMandatory = ""
            if( $mandatoryFields) {
                foreach ($check in $mandatoryFields) {

                    $checkForMandatory += "
if (`$(`".$check`").val() == `"`") {
    event.preventDefault();
    return false;
}
"
                }
            }
            $ajaxPart = if ($Ajax) {
                    
                    $ajaxAction = 
                        if ($action.Contains('?')) {
                            $action + "&Bare=true"
                        } else {
                            if ($action.EndsWith('/')) {
                                $action + "?Bare=true"
                            } else {
                                $action + "/?Bare=true"
                            }
                        }
@"
                    `$('#$($commandMetaData.Name)_Input_$RandomSalt').submit(function(event){
                        var data = `$(this).serialize();
                        if (Form_${RandomSalt}_Submitted == true) {
                            event.preventDefault();
                            return false;
                        }

                        $checkForMandatory
                           
                        `$('input[type=submit]', this).prop('disabled', true);
                        Form_${RandomSalt}_Submitted  =true;
                        setTimeout(
                            function() {
                            `$.ajax({
                                 url: '$ajaxAction',
                                 async: false,                                 
                                 data: data
                            }).done(function(data) {                                
                                    `$('#$($commandMetadata.Name)_InlineOutputContainer_$RandomSalt').html(data);
                                    `$('#$($commandMetaData.Name)_Input_$RandomSalt').hide()
                                    `$('html, body').animate({scrollTop: `$(`"#$($commandMetadata.Name)_InlineOutputContainer_$RandomSalt`").offset().top}, 400); 
                                })                                
                            }, 125);
                        `$( `"#$($commandMetadata.Name)_Undo_$RandomSalt`" ).show();
                        `$( `"#$($commandMetadata.Name)_Undo_$RandomSalt`" ).button().click(
                            function(event) { 
                                `$('input[type=submit]').prop('disabled', false);                                
                                Form_${RandomSalt}_Submitted = false;
                                `$('#$($commandMetadata.Name)_Undo_$RandomSalt').hide()
                                `$('#$($commandMetaData.Name)_Input_$RandomSalt').show()
                                `$('html, body').animate({scrollTop: `$(`"#$($commandMetaData.Name)_Input_$RandomSalt`").offset().top}, 400);    
                                event.preventDefault();
                            });
                        //event.preventDefault();
                        return false;
                    });
"@
            } else {
                ""
            }
            if (-not $TwoColumn) {
                $null = $inputForm.Append("
    
        ")
            } else {
                
                $null = $inputForm.Append("
    <tr>
        <td style='text-align:right;margin-right:15px;padding:15px'>            
        </td>")
            }
            if ($buttonImage) {
                $null = $inputForm.Append("
            <p style='text-align:center;margin-left:15px;padding:15px'>                    
                ")
            } else {
                $null = $inputForm.Append("
            <p style='text-align:center;margin-left:15px;padding:15px'>
                <input type='submit' class='$($commandMetadata.Name)_SubmitButton' value='$buttonText' style='border:1px solid black;padding:5;font-size:large'/>
                
                <script>
                    `$(function() {
                        `$( `".$($commandMetadata.Name)_SubmitButton`" ).button();                        
                        `$( `".$($commandMetadata.Name)_Undo`" ).hide();
                        var Form_${RandomSalt}_Submitted = false;
                        $ajaxPart 

                    })                    
                </script>
                "
                
                
                )
                
            }
            if (-not $twoColumn) {
                # $null = $inputForm.Append("</p>")
            } else {
                $null = $inputForm.Append("</tr>")
            }
        } elseif ($Platform -eq 'Android') {
            $null = $inputForm.Append(@"
    <TableLayout 
        $theDefaultAttributesInAndroidLayout>
	       
           <Button
    	        android:id="@+id/$($idSafeCommandName)_Invoke"
    	        $theDefaultAttributesInAndroidLayout
    	        android:text="$ButtonText" />
	</TableLayout>
"@)            
        } elseif ('WPF', 'WindowsMobile', 'WindowsMetro', 'Win8' -contains $Platform) {
            $null = $inputForm.Append(@"
    <Button HorizontalAlignment='Stretch' x:Name='$($idSafeCommandName)_Invoke' Margin='7'>
        <TextBlock
            $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
            $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
            $MajorStyleChunk
            FontWeight='Bold'            
            Text='$ButtonText' />        
    </Button>
    
"@)         
        }
    }    
        
    
    #endregion
        if ($platform -eq 'Web') {
            $null = $inputForm.Append("
    </div>
</form>
<div class='$($commandMetadata.Name)_ErrorContainer'>
</div>
<div class='$($commandMetadata.Name)_CenterButton' style='text-align:center'>
    <a href='javascript:void' class='$($CommandMetaData.Name)_Undo' id='$($CommandMetaData.Name)_Undo_$RandomSalt' style='display:none;text-align:center;font-size:small'><div class='ui-icon ui-icon-pencil' style='margin-left:auto;margin-right:auto'> </div>Change Input</a>
</div>


")    
        } elseif ($platform -eq 'Android') {
            $null = $inputForm.Append("
    </LinearLayout>
</ScrollView>
</ViewSwitcher>
")    
        } elseif ('AndroidBackEnd' -eq $platform) {
            $null = $inputForm.Append("
        return queryString.toString();
    }
")    
        } elseif ('CSharpBackEnd' -eq $platform) {
            $null = $inputForm.Append("
        return queryString.ToString();
    }
")    
        } elseif ('WPF', 'WindowsMobile', 'WindowsMetro', 'Win8' -contains $Platform) {
            $null = $inputForm.Append(@"
    </StackPanel>
</ScrollViewer>
</Grid>
"@)         
        } elseif ('GoogleGadget' -eq $platform) {
            $null = $inputForm.Append(@"        
</Module>  
"@)        
        } elseif ('TwilML' -eq $platform) {
            $null = $inputForm.Append(@"        
</Response>  
"@)        
        }
        
        $output = "$inputForm"
        
        if ('Android', 'WPF','SilverLight', 'WindowsMobile', 'Metro', 'Win8', 'Web','GoogleGadget', 'TwilML' -contains $platform) {
            if ($output -as [xml]) {            
                # Nice XML Trick
                $strWrite = New-Object IO.StringWriter
                ([xml]$output).Save($strWrite)
                $strWrite = "$strWrite"
                $strWrite.Substring($strWrite.IndexOf('>') + 3)     
            } else {
                $output
            }
        } elseif ($Platform -eq 'PipeworksDirective') {
            $allPipeworksDirectives 
        } else {
            $output
        }
    }
}

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnDWN9Wv9pHN9si+WP4iyaqZg
# hA6gggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFE4uQtnYrbJTUGLr
# sFkguc0/efZGMA0GCSqGSIb3DQEBAQUABIIBAEI+WTs0I1vypv1AfR5P1s+pfKbG
# 7CXmQUuowA7tFTvcJ+jiXN26eEXU0rSIDPSgjuPVqfbiKJ9uVDbQgp11yC5XNAj5
# aQ74az6uRz83J8vmlN321gonyVVf2ooCMIFZ/VGGm9sYjjGKGflLq0ZcYbNHL05J
# wInkGWngb8NkAEs8Q1x7avDCNUJmnR0TgnufUHLs8/jCs26HzfHAPBfGsAlEzz6N
# a2e7d4NWpDX5Oy/Qr9VOhuOc+sYQHXyNa3adi1JzPxcsOiDp2aGTsvMd8uPiku7F
# 8LxNi0gagiqmNTU4jXFnrUw2V1Po8cnF8BZY/KM69+dohZA99X8pFii9qa4=
# SIG # End signature block
