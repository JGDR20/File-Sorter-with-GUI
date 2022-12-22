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
	#Get-Variable var_*
}

# Start the sorting process
function Start-Sort ($StartDate, $EndDate, $Source, $Destination, $Include, $Description, $Output) {
    ## Dates to copmpare
    $Today = (Get-Date).Date

    ## Prepend " - " to $description if populated, else leave blank
    If (($Description) -and ($Description -ne "Description to append to destination")) {
	    $DescriptionFinal = " - " + $Description
    }

    ## Output the settings to the user
    If (($Include -eq "File Types") -or ($Include -eq "All") -or (!$Include)) {
	    $IncludeArray = @("*.*")
    } else {
        $IncludeArray = $Include -Split '[,\s\t]+'
    }
    
    $Output = ($Output + "`nCopying files between " + $StartDate.ToString("yyyy-MM-dd") + " and " + $EndDate.ToString("yyyy-MM-dd"))
    $Output = ($Output + "`nFrom " + $Source + " to " + $Destination)
    If ($DescriptionFinal) {
	    $Output = ($Output +  "`nAdding `"$($Description)`" to the dated folders")
    }
    $Output = ($Output + "`nUsing these file filters: " + $IncludeArray)

    $script:var_txtOutput.Text = $Output

    # Find all '-include'ed files in $source, created within the date range specified
    # Add -recursive to Get-ChildItem in the below line (before the | ) to search subdirectories
    Get-ChildItem -File -Path "$($Source)\*" -Include $IncludeArray |
	    # Compare the creation dates only (remove time - e.g. 2001-03-24 06:00:00 becomes 2001-03-24)
	    Where-Object {($_.CreationTime).Date -ge $StartDate `
			    -and ($_.CreationTime).Date -le $EndDate} |
	    # For each file found...
	    ForEach-Object {
		    # Create a destination folder (destination\date - description\file extension
            $Folder = Join-Path -Path $Destination -ChildPath (($_.CreationTime).ToString("yyyy-MM-dd") + $DescriptionFinal)
		    $Folder = Join-Path -Path $Folder -ChildPath ($_.Extension).Substring(1).ToUpper()
		    $File = Join-Path -Path $Folder -ChildPath $_.Name
		
		    # See if the destination folder already exists and create it if not
		    If (!(Test-Path $Folder -PathType Container))
			    {
                $Output = ($Output + "`n[+] Creating $Folder\")
                $script:var_txtOutput.Text = $Output
			    New-Item -ItemType Directory -Path $Folder
			    }
		
		    # Test if the file exists in destination and copy if not
		    If (Test-Path -Path $File)
			    {
			    $Output = ($Output + "`n[-] " + $_.Name + " exists in $Folder\")
                $script:var_txtOutput.Text = $Output
                #Write-Host [-] $_.Name exists in $Folder\
                $Script:skipCounter++
			    $Script:var_txtSkipped.Text = $Script:skipCounter
			    }
		    Else
			    {
                $Output = ($Output + "`n[+] Copying: " + $_.Name + " to $Folder\")
                $script:var_txtOutput.Text = $Output
			    #Write-Host [+] Copying: $_.Name to $Folder\
			    Copy-Item -Path $_.FullName -Destination $Folder
                $Script:copyCounter++
			    $Script:var_txtCopied.Text = $Script:copyCounter
			    }
		    }

    
    $Output = ($Output + "`nFinished copying " + $copyCounter + " files, skipped " + $skipCounter)
    $script:var_txtOutput.Text = $Output
    #Write-Host "Finished copying $copyCounter files, skipped $skipCounter"
    #Read-Host -Prompt 'Press Enter to exit'
}

# Set Dates
function Set-Date ($date) {
    If (!$date) {
        $date = (Get-Date).Date
    }
    
    return $date
}

# Set Include Filter Array
function Set-IncludeArray ($Include) {
    $IncludeArray=$Include.Split(",")
}

## Checks
# Check Dates
function Check-Dates ($StartDate, $EndDate) {
    If ($StartDate -gt $EndDate) {
        $script:Output = ($script:Output + "`n" + $StatusTable['DateSwap'])
        return $true
    } else {
        return $false
    }
}

# Check Paths
function Check-Paths ($DirPath) {
    If (Test-Path $DirPath) {
        return $false
    } else {
        $script:Output = ($script:Output + "`n" + $StatusTable['Paths'] + $DirPath)
        return $true
    }
}

# Check wrapper
function Check-FormData ($StartDate, $EndDate, $Source, $Destination, $Include, $Description, $Output) {
    #Write-Host Beginning Checks
    $ErrorDates = Check-Dates -StartDate $StartDate -EndDate $EndDate
    $ErrorSource = Check-Paths -DirPath $Source
    $ErrorDestination = Check-Paths -DirPath $Destination
    If ($ErrorDates -or $ErrorSource -or $ErrorDestination) {
        $script:var_txtOutput.Text = $script:Output
    } else {
        Start-Sort -StartDate $StartDate -EndDate $EndDate -Source $Source -Destination $Destination -Include $Include -Description $Description -Output $Output
    }
}


## Variables
# Counters to output number of files copied and skipped
[int]$copyCounter = 0
[int]$skipCounter = 0
#Write-Host Counters Set

# StatusTable
[hashtable]$StatusTable = @{
    DateSwap = "Start Date is after End Date"
    Paths = "Please check directory path: "
}
#Write-Host Statuses Set

# Output
[string]$Output = ""
#Write-Host Output Set

# Get Window Details and Setup Prompts
Initialize-WPF
#Write-Host Window Drawn

# On Clicking Go button
$var_btnGo.Add_Click({
    #Write-Host Button Clicked
    $script:Output = "Running"
    #Write-Host $Output
    $script:var_txtOutput.Text = $Output
    #Write-Host $var_txtOutput.Text

    $script:copyCounter = 0
    $script:skipCounter = 0
    $script:var_txtCopied.Text = 0
    $script:var_txtSkipped.Text = 0
    #Write-Host Counters Set again

    #Write-Host $script:var_dtStart.SelectedDate
    $script:var_dtStart.SelectedDate = Set-Date($script:var_dtStart.SelectedDate)
    $script:var_dtEnd.SelectedDate = Set-Date($script:var_dtEnd.SelectedDate)
    #Write-Host Dates Set
    
    Check-FormData -StartDate $var_dtStart.SelectedDate -EndDate $var_dtEnd.SelectedDate -Source $var_txtSrc.Text -Destination $var_txtDest.Text -Include $var_txtInclude.Text -Description $var_txtDesc.Text -Output $var_txtOutput.Text
    #$script:Output = "Output"
})

$Null = $window.ShowDialog()