### CHANGE DEFAULTS in $defaultVals hashtable below!!!
## Parameters for $daysOldest, $daysNewest (counting back from now)
## $description name (allows blank/null)
## $source and $destination directories
## $include extension filter e.g. *.jpg, *.avi as an array with one extension per element
##	# example: include[0]: *.jpg - include[1]: *.avi

## Add Presentation Framework
Add-Type -AssemblyName PresentationFramework

## Stop running the script if any errors occur
$ErrorActionPreference = "Stop"

## Functions:
# Read and prepare WPF files
function Initialize-WPF {
	# XML file location
	$xamlFile = Resolve-Path -Path ("$PSScriptRoot\GUI.xaml")

	# Create window
	$inputXML = Get-Content $xamlFile -Raw
	$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
	[XML]$XAML = $inputXML

	# Read XAML
	$reader = (New-Object System.Xml.XmlNodeReader $xaml)
	try {
	    $script:window = [Windows.Markup.XamlReader]::Load( $reader )
	} catch {
	    Write-Warning $_.Exception
	    throw
	}

	# Create variables based on form control names.
	# Variable will be named as 'var_<control name>'

	$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
	    #"trying item $($_.Name)"
	    try {
	        Set-Variable -Name "var_$($_.Name)" -Value $window.FindName($_.Name) -ErrorAction Stop -Scope Script
	    } catch {
	        throw
	    }
	}
	Get-Variable var_*
}

function Register-Prompts {
    [CmdletBinding()]
    Param(
		    [Parameter(Mandatory=$True)]
		    [AllowNull()]
		    [ValidateScript({$_ -ge 0})]
		    [int]
		    $daysOldest
	    ,
		    [Parameter(Mandatory=$True)]
		    [AllowNull()]
		    [ValidateScript({$_ -ge 0 -and $_ -le $daysOldest})]
		    [int]
		    $daysNewest
	    ,
		    [Parameter(Mandatory=$True)]
		    [AllowEmptyString()]
		    [string]
		    $description
	    ,
		    [Parameter(Mandatory=$True)]
		    [AllowEmptyString()]
		    [ValidateScript({If($_) {Test-Path $_} Else {$true}})]
		    [string]
		    $source
	    ,
		    [Parameter(Mandatory=$True)]
		    [AllowEmptyString()]
		    [ValidateScript({If($_) {Test-Path $_} Else {$true}})]
		    [string]
		    $destination
	    ,
		    [Parameter(Mandatory=$True)]
		    [AllowEmptyCollection()]
		    [string[]]
		    $include
    )
}

# Prepare running variables with prompt values if present, otherwise defaults
function Running-Variables ($promptVal, $defaultVal) {
	If ($promptVal) {
		$running = $promptVal
	} Else {
		$running = $defaultVal
	}
	return $running
}

# Start the sorting process
function Start-Sort {
    # Check and load variables from $defaultVals into $runningVals if $runningVals is blank/empty for each key
    ForEach ($key in $defaultVals.Keys) {
	    $runningVals[$key] = Running-Variables -promptVal $runningVals[$key] -defaultVal $defaultVals[$key]
    }

    ## Counters to output number of files copied and skipped
    [int]$copyCounter = 0
    [int]$skipCounter = 0

    ## Dates to copmpare
    $Today = (Get-Date).Date
    $StartDate = $Today.AddDays(-$runningVals.daysOldest)
    $EndDate = $Today.AddDays(-$runningVals.daysNewest)

    ## Prepend " - " to $description if populated, else leave blank
    If ($runningVals.description) {
	    $runningVals.description = " - " + $runningVals.description
    }

    ## Output the settings to the user
    Write-Host Copying files between ($StartDate).ToString("yyyy-MM-dd") and ($EndDate).ToString("yyyy-MM-dd")
    Write-Host From $runningVals.source to $runningVals.destination
    If ($runningVals.description) {
	    Write-Host "Adding `"$($runningVals.description)`" to the dated folders"
    }
    Write-Host Using these extensions only: $runningVals.include

    # Find all '-include'ed files in $source, created within the date range specified
    # Add -recursive to Get-ChildItem in the below line (before the | ) to search subdirectories
    <#
    Get-ChildItem -Path "$($runningVals.source)\*" -Include $runningVals.include |
	    # Compare the creation dates only (remove time - e.g. 2001-03-24 06:00:00 becomes 2001-03-24)
	    Where-Object {($_.CreationTime).Date -ge $StartDate `
			    -and ($_.CreationTime).Date -le $EndDate} |
	    # For each file found...
	    ForEach-Object {
		    # Create a destination folder (destination\date - description\file extension
		    $Folder = Join-Path -Path $runningVals.destination -ChildPath (($_.CreationTime).ToString("yyyy-MM-dd") + $runningVals.description)
		    $Folder = Join-Path -Path $Folder -ChildPath ($_.Extension).Substring(1).ToUpper()
		    $File = Join-Path -Path $Folder -ChildPath $_.Name
		
		    # See if the destination folder already exists and create it if not
		    If (!(Test-Path $Folder -PathType Container))
			    {
			    New-Item -ItemType Directory -Path $Folder
			    }
		
		    # Test if the file exists in destination and copy if not
		    If (Test-Path -Path $File)
			    {
			    Write-Host [-] $_.Name exists in $Folder\
			    $Script:skipCounter++
			    }
		    Else
			    {
			    Write-Host [+] Copying: $_.Name to $Folder\
			    Copy-Item -Path $_.FullName -Destination $Folder
			    $Script:copyCounter++
			    }
		    }
    #>

    ## Clean-up
    Remove-Variable -name defaultVals
    Remove-Variable -name runningVals

    Write-Host "Finished copying $copyCounter files, skipped $skipCounter"
    Read-Host -Prompt 'Press Enter to exit'
}

# On Clicking Go button
$var_btnGo.Add_Click

Initialize-WPF
Register-Prompts

## Default Values hashtable
## CHANGE ME ##
$defaultVals = @{
	daysOldest = 0;
	daysNewest = 0;
	description = '';
	source = $var_txtSrc.Text;
	destination = 'D:\User\Documents\Some\Destination';
	include = @(
		'*'
	)
}

## Running Values hashtable
$runningVals = @{
	daysOldest = $daysOldest;
	daysNewest = $daysNewest;
	description = $description;
	source = $source;
	destination = $destination;
	include = $include
}

$Null = $window.ShowDialog()