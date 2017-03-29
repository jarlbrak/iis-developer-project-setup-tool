<#
        .SYNOPSIS
        This script is intended to be compiled into an exe for use by development teams for creating full tiered applications with one click
        .DESCRIPTION
        This script uses several functions from the Carbon project in order to properly edit the hosts file to allow for developers to simulate dns entries for thier sites.
        It looks for a file called SiteList.json that is formatted in a certain way that is easily scalable and easily changed for each project.
        This script must be run as an administrator and is designed for Powershell v4+
        .EXAMPLE
        Convert this script into an exe using the tool called "PS2EXE". Properly format your JSON data file like the included example. Right click and run the exe as administrator.
        .NOTES
        IIS Developer Project Setup Tool v1.0
        
        Author: Thomas Brackin

        Carbon Functions Author: Aaron Jensen

        Requires: Powershell v4.0+

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

Import-Module WebAdministration

function Use-CallerPreference{
    # Licensed under the Apache License, Version 2.0 (the "License");
    # you may not use this file except in compliance with the License.
    # You may obtain a copy of the License at
    # 
    #     http://www.apache.org/licenses/LICENSE-2.0
    # 
    # Unless required by applicable law or agreed to in writing, software
    # distributed under the License is distributed on an "AS IS" BASIS,
    # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    # See the License for the specific language governing permissions and
    # limitations under the License.
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        #[Management.Automation.PSScriptCmdlet]
        # The module function's `$PSCmdlet` object. Requires the function be decorated with the `[CmdletBinding()]` attribute.
        $Cmdlet,

        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState]
        # The module function's `$ExecutionContext.SessionState` object. Requires the function be decorated with the `[CmdletBinding()]` attribute. 
        #
        # Used to set variables in its callers' scope, even if that caller is in a different script module.
        $SessionState
    )

    Set-StrictMode -Version 'Latest'

    # List of preference variables taken from the about_Preference_Variables and their common parameter name (taken from about_CommonParameters).
    $commonPreferences = @{
                              'ErrorActionPreference' = 'ErrorAction';
                              'DebugPreference' = 'Debug';
                              'ConfirmPreference' = 'Confirm';
                              'InformationPreference' = 'InformationAction';
                              'VerbosePreference' = 'Verbose';
                              'WarningPreference' = 'WarningAction';
                              'WhatIfPreference' = 'WhatIf';
                          }

    foreach( $prefName in $commonPreferences.Keys )
    {
        $parameterName = $commonPreferences[$prefName]

        # Don't do anything if the parameter was passed in.
        if( $Cmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName) )
        {
            continue
        }

        $variable = $Cmdlet.SessionState.PSVariable.Get($prefName)
        # Don't do anything if caller didn't use a common parameter.
        if( -not $variable )
        {
            continue
        }

        if( $SessionState -eq $ExecutionContext.SessionState )
        {
            Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
        }
        else
        {
            $SessionState.PSVariable.Set($variable.Name, $variable.Value)
        }
    }

}

function Get-PathToHostsFile{
    # Licensed under the Apache License, Version 2.0 (the "License");
    # you may not use this file except in compliance with the License.
    # You may obtain a copy of the License at
    # 
    #     http://www.apache.org/licenses/LICENSE-2.0
    # 
    # Unless required by applicable law or agreed to in writing, software
    # distributed under the License is distributed on an "AS IS" BASIS,
    # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    # See the License for the specific language governing permissions and
    # limitations under the License.
    [CmdletBinding()]
    param(
    )

    Set-StrictMode -Version 'Latest'

    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    return Join-Path $env:windir system32\drivers\etc\hosts
}

function Read-File{
    # Licensed under the Apache License, Version 2.0 (the "License");
    # you may not use this file except in compliance with the License.
    # You may obtain a copy of the License at
    # 
    #     http://www.apache.org/licenses/LICENSE-2.0
    # 
    # Unless required by applicable law or agreed to in writing, software
    # distributed under the License is distributed on an "AS IS" BASIS,
    # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    # See the License for the specific language governing permissions and
    # limitations under the License.
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        $Path,
        [int]
        $MaximumTries = 30,
        [int]
        $RetryDelayMilliseconds = 100,
        [Switch]
        $Raw
    )
    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    $Path = Resolve-Path -Path $Path
    if(-not $Path){
        return
    }

    $tryNum = 1
    $output = @()
    do{
        $lastTry = $tryNum -eq $MaximumTries
        if($lastTry){
            $errorAction = @{}
        }

        $cmdErrors = @()
        $numErrorsAtStart = $Global:Error.Count
        try{
            if($Raw){
                $output = [IO.File]::ReadAllText($Path)
            }
            else{
                $output = Get-Content -Path $Path -ErrorAction SilentlyContinue -ErrorVariable 'cmdErrors'
                if( $cmdErrors -and $lastTry ){
                    foreach( $item in $cmdErrors ){
                        $Global:Error.RemoveAt(0)
                    }
                    $cmdErrors | Write-Error 
                }
            }
        }
        catch{
            if( $lastTry ){
                Write-Error -ErrorRecord $_
            }
        }

        $numErrors = $Global:Error.Count - $numErrorsAtStart

        if( -not $lastTry ){
            for( $idx = 0; $idx -lt $numErrors; ++$idx ){
                $Global:Error[0] | Out-String | Write-Debug
                $Global:Error.RemoveAt(0)
            }
        }
        if( $cmdErrors -or $numErrors ){
            if( -not $lastTry ){
                Write-Debug -Message ('Failed to read file ''{0}'' (attempt #{1}). Retrying in {2} milliseconds.' -f $Path,$tryNum,$RetryDelayMilliseconds)
                Start-Sleep -Milliseconds $RetryDelayMilliseconds
            }
        }
        else{
            return $output
        }
    }
    while( $tryNum++ -lt $MaximumTries )
}

function Write-File{
    # Licensed under the Apache License, Version 2.0 (the "License");
    # you may not use this file except in compliance with the License.
    # You may obtain a copy of the License at
    # 
    #     http://www.apache.org/licenses/LICENSE-2.0
    # 
    # Unless required by applicable law or agreed to in writing, software
    # distributed under the License is distributed on an "AS IS" BASIS,
    # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    # See the License for the specific language governing permissions and
    # limitations under the License.
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        $Path,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]
        $InputObject,
        [int]
        $MaximumTries = 30,
        [int]
        $RetryDelayMilliseconds = 100
    )
    begin{
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState
        $Path = Resolve-Path -Path $Path
        if( -not $Path ){
            return
        }
        $content = New-Object -TypeName 'Collections.Generic.List[object]'
    }
    process{
        if( -not $Path ){
            return
        }
        $InputObject | ForEach-Object { $content.Add( $_ ) } | Out-Null
    }

    end{
        if( -not $Path ){
            return
        }
        $cmdErrors = @()
        $tryNum = 1
        $errorAction = @{ 'ErrorAction' = 'SilentlyContinue' }
        do{
            $exception = $false
            $lastTry = $tryNum -eq $MaximumTries
            if( $lastTry ){
                $errorAction = @{}
            }
            $numErrorsAtStart = $Global:Error.Count
            try{
                Set-Content -Path $Path -Value $content @errorAction -ErrorVariable 'cmdErrors'
            }
            catch{
                if( $lastTry ){
                    Write-Error -ErrorRecord $_
                }
            }
            $numErrors = $Global:Error.Count - $numErrorsAtStart
            if( $numErrors -and -not $lastTry ){
                for( $idx = 0; $idx -lt $numErrors; ++$idx ){
                    $Global:Error[0] | Out-String | Write-Debug
                    $Global:Error.RemoveAt(0)
                }
            }
            if( $cmdErrors -or $numErrors ){
                if( -not $lastTry ){
                    Write-Debug -Message ('Failed to write file ''{0}'' (attempt #{1}). Retrying in {2} milliseconds.' -f $Path,$tryNum,$RetryDelayMilliseconds)
                    Start-Sleep -Milliseconds $RetryDelayMilliseconds
                }
            }
            else{
                break
            }
        }
        while( $tryNum++ -le $MaximumTries )
    }
}

function Set-HostsEntry{
    # Licensed under the Apache License, Version 2.0 (the "License");
    # you may not use this file except in compliance with the License.
    # You may obtain a copy of the License at
    # 
    #     http://www.apache.org/licenses/LICENSE-2.0
    # 
    # Unless required by applicable law or agreed to in writing, software
    # distributed under the License is distributed on an "AS IS" BASIS,
    # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    # See the License for the specific language governing permissions and
    # limitations under the License.
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [Net.IPAddress]
        $IPAddress,
        [Parameter(Mandatory=$true)]
        [string]
        $HostName,
        [string]
        $Description,
        [string]
        $Path = (Get-PathToHostsFile)
    )
    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState
    $matchPattern = '^(?<IP>[0-9a-f.:]+)\s+(?<HostName>[^\s#]+)(?<Tail>.*)$'  
    $lineFormat = "{0,-45}  {1}{2}"
    if(-not (Test-Path $Path)){
        Write-Warning "Creating hosts file at: $Path"
        New-Item $Path -ItemType File
    }
    [string[]]$lines = Read-File -Path $Path -ErrorVariable 'cmdErrors'
    if( $cmdErrors ){
        return
    }    
    $outLines = New-Object 'Collections.ArrayList'
    $found = $false
    $lineNum = 0
    $updateHostsFile = $false
    foreach($line in $lines){
        $lineNum += 1
        if($line.Trim().StartsWith("#") -or ($line.Trim() -eq '') ){
            [void] $outlines.Add($line)
        }
        elseif($line -match $matchPattern){
            $ip = $matches["IP"]
            $hn = $matches["HostName"]
            $tail = $matches["Tail"].Trim()
            if( $HostName -eq $hn ){
                if($found){
                    [void] $outlines.Add("#$line")
                    $updateHostsFile = $true
                    continue
                }
                $ip = $IPAddress
                $tail = if( $Description ) { "`t# $Description" } else { '' }
                $found = $true   
            }
            else{
                $tail = "`t{0}" -f $tail
            }
           
            if( $tail.Trim() -eq "#" ){
                $tail = ""
            }
            $outline = $lineformat -f $ip, $hn, $tail
            $outline = $outline.Trim()
            if( $outline -ne $line ){
                $updateHostsFile = $true
            }
            [void] $outlines.Add($outline)  
        }
        else{
            Write-Warning ("Hosts file {0}: line {1}: invalid entry: {2}" -f $Path,$lineNum,$line)
            $outlines.Add( ('# {0}' -f $line) )
        }
    }
    if(-not $found){
       $tail = "`t# $Description"
       if($tail.Trim() -eq "#"){
           $tail = ""
       }
       $outline = $lineformat -f $IPAddress, $HostName, $tail
       $outline = $outline.Trim()
       [void] $outlines.Add($outline)
       $updateHostsFile = $true
    }
    if( -not $updateHostsFile ){
        return
    }
    Write-Verbose -Message ('[HOSTS]  [{0}]  {1,-45}  {2}' -f $Path,$IPAddress,$HostName)
    $outLines | Write-File -Path $Path
}

# Parameters Required: [string]$siteName - this is the name of the site you want to create
#                      [system.object]$tier - this is the object containing information about the tier you want to create
#                      [boolean]$parentSite - this is a boolean to determine if the site has a parent site
# This function will create a top level website with the given parameters.
function CreateWebSite ([string]$siteName, [system.object]$tier, [boolean]$parentSite){
    if ($parentSite){
        $siteName = $tier.parentSite
        $url = $tier.parentSite
        $physicalPath = $tier.parentSitePhysicalPath
    }
    else{
        $url = $tier.url
        $physicalPath = $tier.physicalPath
    }

    if(!(Test-Path IIS:\AppPools\$siteName)){
        New-Item IIS:\AppPools\$siteName
    }

    if(!(Test-Path IIS:\Sites\$siteName)){
        New-Website -Name $siteName -PhysicalPath $physicalPath -ApplicationPool $siteName -HostHeader $url
        Set-HostsEntry -IPAddress 127.0.0.1 -HostName $url -Description $siteName
    }
}

# Parameters Required: [system.object]$site - this is the full site object that you want to create
#                      [string]$tier - this is the name of the tier that should be created. This is typically arranged in heirarchy of app (presentation layer), biz (application layer), and dat (data layer).
# This function will create a web application with the given parameters. It will also create a top level site if a parent is specified that does not exist.
function CreateWebApplication([system.object]$site, [string]$tier){
    $appPool = ($site.name + "_" + $tier)

    if(!(Test-Path IIS:\AppPools\$appPool)){
        New-Item IIS:\AppPools\$appPool
    }

    if(!(Test-Path IIS:\Sites\$site.$tier.parentSite)){
        CreateWebSite -siteName $site.$tier.parentSite -tier $site.$tier -parentSite $true
    }
    if(Test-Path $site.$tier.physicalPath){
        New-WebApplication -ApplicationPool $appPool -PhysicalPath $site.$tier.physicalPath -Name $site.$tier.appPath -Site $site.$tier.parentSite
    }
}

# Parameters Required: [system.object]$site - this is the full site object that you want to create
# This function will create the web sites and web applications in a tiered architecture typically seen in ASP .NET web projects.
function CreateTiers ([system.object] $site){
    If ($site.appTier){
        If ($site.appTier.parentSite){
            CreateWebApplication -site $site -tier "appTier"
        }
        Else {
            CreateWebsite -siteName $site.appTier.url -tier $site.appTier
        }
    }
    If ($site.bizTier){
        If ($site.bizTier.parentSite){
            CreateWebApplication -site $site -tier "bizTier"
        }
        Else {
            CreateWebsite -siteName $site.bizTier.url -tier $site.bizTier
        }
    }
    If ($site.datTier){
        If ($site.datTier.parentSite){
            CreateWebApplication -site $site -tier "datTier"
        }
        Else {
            CreateWebsite -siteName $site.datTier.url -tier $site.datTier
        }
    }
}

# Main
$jsonObject = ConvertFrom-Json "$(get-content .\SiteList.json)"

ForEach ($site in $jsonObject.sites){
    CreateTiers -site $site
}