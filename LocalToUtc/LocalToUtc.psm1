﻿function Convert-UtcToLocal
{
<#
.Synopsis
    Converts UTC time to the system local time.
.Description
    Converts the current UTC time to the local system time, using the local system's timezone.
    To override the UTC Time, enter an ISO 8601 string (ex: "2017-08-01 09:20:00") as a parameter.
    To override the Time Zone use any of the time zone strings listed in https://msdn.microsoft.com/en-us/library/cc749073.aspx
.Example
    Convert-UtcToLocal -AddHours -3 -UtcTime "2017-08-01 03:00:00"
.Example
    Convert-UtcToLocal -TimeZone "Pacific Standard Time"
#>
    [CmdletBinding()]
    
    param(
    [parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [String] $Time,
    [String] $TimeZone,
    [Int] $AddDays,
    [Int] $AddHours,
    [Int] $AddMinutes
    )

    Process {
        $utc = Get-UtcTime
        $local = Get-LocalTime $utc
        $tzone = if ($TimeZone) { $TimeZone } else { Invoke-GetTimeZone }

        if ($Time) { $utc = Get-Date $Time }
        if ($AddDays) { $utc = $utc.AddDays($AddDays) }
        if ($AddHours) { $utc = $utc.AddHours($AddHours) }
        if ($AddMinutes) { $utc = $utc.AddMinutes($AddMinutes) }

        $local = Convert-TimeZone $utc -FromTimeZone "UTC" -ToTimeZone $tzone

        $IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
        if ($IsVerbose -eq $true) {
            $tz = [TimeZoneInfo]::FindSystemTimeZoneById($tzone)
            $converted = New-Object psobject -Property @{ UtcTime=$utc; LocalTime=$local; TimeZone=$tz }
            return $converted
        }

        return $local
    }
}

function Convert-LocalToUtc
{
<#
.Synopsis
    Converts the local system time to UTC time
.Description
    Converts the current local system time to UTC time, using the local system's timezone.
    To override the local time, enter an ISO 8601 string (ex: "2017-08-01 09:20:00") as a parameter.
    To override the Time Zone use any of the strings listed in https://msdn.microsoft.com/en-us/library/cc749073.aspx
.Example
    Convert-LocalToUtc -AddHours 5
.Example
    Convert-LocalToUtc -TimeZone "Pacific Standard Time"
#>
    [CmdletBinding()]

    param(
    [parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [String] $Time,
    [String] $TimeZone,
    [Int] $AddDays,
    [Int] $AddHours,
    [Int] $AddMinutes
    )

    Process {
        $utc = Get-UtcTime
        $local = Get-LocalTime $utc
        $tzone = Invoke-GetTimeZone

        if ($Time) { $local = Get-Date $Time }
        if ($AddDays) { $local = $local.AddDays($AddDays) }
        if ($AddHours) { $local = $local.AddHours($AddHours) }
        if ($AddMinutes) { $local = $local.AddMinutes($AddMinutes) }

        # If a time is not defined, but a timezone is, then treat the
        # current local system time as the local time of the specified timezone
        if (! $Time -and $TimeZone) {
            $FromTimeZone = [TimeZoneInfo]::FindSystemTimeZoneById($tzone)
            $ToTimeZone = [TimeZoneInfo]::FindSystemTimeZoneById($TimeZone)
            $local = [TimeZoneInfo]::ConvertTime($local, $FromTimeZone, $ToTimeZone)
        }

        if ($TimeZone) { $tzone = $TimeZone }

        $utc = Convert-TimeZone $local -FromTimeZone $tzone -ToTimeZone "UTC"
        $IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
        if ($IsVerbose -eq $true) {
            $converted = New-Object psobject -Property @{ UtcTime=$utc; LocalTime=$local; TimeZone=$tzone }
            return $converted
        }

        return $utc
    }
}

function Convert-TimeZone
{
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String] $Time,
        [String] $ToTimeZone,
        [String] $FromTimeZone
    )

    Process {
        # always start with the current utc time if $Time is not set
        $fromTimeUtc = Get-UtcTime

        # if from time zone is not specified, use the current system timezone
        $fromTz = Invoke-GetTimeZone
        if ($FromTimeZone) {
            $fromTz = [TimeZoneInfo]::FindSystemTimeZoneById($FromTimeZone)
        }

        $toTz = [TimeZoneInfo]::FindSystemTimeZoneById($ToTimeZone)

        # convert the input time to utc using the FromTimeZone
        if ($Time) {
            $fromTimeKind = [System.DateTime]::SpecifyKind($Time, [System.DateTimeKind]::Unspecified)
            $fromTimeUtc = [TimeZoneInfo]::ConvertTimeToUTC($fromTimeKind, $fromTz)
        }

        # use the current utc time to find the time in the destination timezone
        $toTimeKind = [System.DateTime]::SpecifyKind($fromTimeUtc, [System.DateTimeKind]::Unspecified)
        $toTime = [TimeZoneInfo]::ConvertTimeFromUTC($toTimeKind, $toTz)

        return $toTime
    }
}

# overloaded to help with testing
function Get-UtcTime { return [System.DateTime]::UtcNow }
function Get-LocalTime ($time) { return $time.ToLocalTime() }
function Invoke-GetTimeZone {
    if (Get-Command Get-TimeZone -errorAction SilentlyContinue) {
        return Get-TimeZone | Select-Object -ExpandProperty Id
    }
    
    return tzutil /g
}
