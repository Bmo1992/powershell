Function Get-OldUser
{
    <#
        .SYNOPSIS
          See who has not logged into the domain in a certain number of days.

        .DESCRIPTION
          Get all users who have not logged into the domain in the numbers of days specified by the NumDays argument. In order to run you
          must be connected to a domain controller and have adequate permissions to view the attributes of active directory objects.

        .PARAMETER NumDays
          Specifically the number of days before the current date you want to set. Any account that has not checked in since that date
          is displayed with the last known logon date

        .PARAMETER ExportCSV
          Export the information to a csv file thats been specified by its path.

        .EXAMPLE
          Get-OldUser -NumDays 30

          Gets all users who have not checked into the domain in 30 days or more and prints the info to stdout. 

        .EXAMPLE
          Get-OldUser -NumDays 20 -ExportCSV C:\Users\jdoe\Documents\user_export.csv

          Gets all users who have not checked into the domain in 20 days or more and exports that information to the csv file 
          C:\Users\jdoe\Documents\user_export.csv

        .NOTES
          NAME    : Get-OldUser
          AUTHOR  : BMO
          EMAIL   : brandonseahorse@gmail.com
          GITHUB  : github.com/Bmo1992
          CREATED : September 17, 2018
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(
            Mandatory=$True
        )]
        [int]$NumDays,
        [Parameter(
        )]
        [String]$ExportCSV
    )

    # Check to confirm this script is being run by an admin in an elevated powershell prompt or else exit. If run from a non-priviledged
    # prompt then powershell will be unabled to read the Enabled AD property thanks to UAC
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal] $identity
    $role = [System.Security.Principal.WindowsBuiltInRole] "Administrator"

    if(-not $principal.IsInRole($role))
    {
        Throw "This script requires elevated permissions, please confirm youre running from an elevated powershell prompt as an administrator"
    }

    # Check to see if the ActiveDirectory module is installed or if we're connected to a remote computer with the module imported to the PS 
    # session.  If not exit the script and warn the user.
    if(-Not (Get-Module ActiveDirectory))
    {
        $modules = Get-Module

        if((Get-Module -ListAvailable).Name -match "ActiveDirectory")
        {
            Import-Module ActiveDirectory
        }
        elseif($modules.ExportedCommands.Values -match "Set-ADUser")
        {
            Write-Host "Connected to $((Get-PSSession).ComputerName), running script against the remote PC" -ForegroundColor Magenta
        }
        else
        {
            Write-Error "No local or remote computer with the ActiveDirectory powershell module found. Please log into a computer with the correct roles installed or establish a remote PS session with that computer" -ErrorAction Stop
        }
    }

    ######## VARIABLES ##########

    $daysback = "-($NumDays)"
    $current_date = Get-Date
    $month_old = $current_date.AddDays($daysback)
    $all_user_objects = Get-ADUser -Filter * -Properties * | ?{ $_.Enabled -eq $True }  

    ############ MAIN ############

    $user_list_scrubbed = ForEach($user in $all_user_objects) 
    {
        if( $user.LastLogonDate -lt $month_old )
        {
            $user
        }
    } 

    # Format the output into a nice readable table
    $user_paramcheck = $user_list_scrubbed | Select-Object `
        @{
            Expression={
                $_.Name
            };
            Label="Name"
        },
        @{
            Expression={
                $_.LastLogonDate
            };
            Label="Last Logon"
        } 

    if($ExportCSV)
    {
        $user_paramcheck | Export-CSV $ExportCSV
    }
    else
    {
        $user_paramcheck | Format-Table
    }
}
