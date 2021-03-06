﻿#Requires -Module Pester

if ((Get-Module).Name -contains 'LocalToUtc') {
    Remove-Module -Name LocalToUtc
}

Remove-Module -Name LocalToUtc -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\LocalToUtc\LocalToUtc.psm1"

Describe 'LocalToUtc' {
    $testTime = "2017-09-04 08:25:00"

    Context 'Time Conversion' {
        It 'Returns a time if no parameters are set' {
            $result = Convert-LocalToUtc
            $result | Should BeOfType [System.DateTime]
        }

        It 'Parses ISO8601 properly' {
            $result = Convert-LocalToUTC -Time $testTime -Verbose
            $expected = Get-Date $testTime
            $result.LocalTime | Should Be $expected
        }

        It 'Converts local time to UTC time when the local time is defined' {
            $result = Convert-LocalToUTC -Time $testTime -TimeZone "Eastern Standard Time" -Verbose
            $expectedUtc = (Get-Date $testTime).AddHours(4)
            $expectedLocal = Get-Date $testTime
            $result.UtcTime | Should Be $expectedUtc
            $result.LocalTime | Should Be $expectedLocal
        }

        It 'Treats the current local time as the specified timezone local time' {
            Mock -ModuleName LocalToUtc Invoke-GetTimeZone {
                return "Central Standard Time"
            }
            Mock -ModuleName LocalToUtc Get-UtcTime {
                $utcTime = Get-Date "2017-09-04 08:25:00"
                $utc = [System.DateTime]::SpecifyKind($utcTime, [System.DateTimeKind]::Utc)
                return $utc
            }
            Mock -ModuleName LocalToUtc Get-LocalTime {
                $utcTime = Get-Date "2017-09-04 08:25:00"
                $cstTime = $utcTime.AddHours(-5)
                return $cstTime
            }

            # current time in UTC - "2017-09-04 08:25:00"
            # current time in CST - "2017-09-04 03:25:00"
            # 3:25am PST   in UTC - "2017-09-04 10:25:00"
            $pstTime = Get-Date "2017-09-04 03:25:00"
            $utcTime = $pstTime.AddHours(7)

            $result = Convert-LocalToUTC -TimeZone "Pacific Standard Time" -Verbose
            $result.UtcTime | Should Be (Get-Date $utcTime)
            $result.LocalTime | Should Be (Get-Date $pstTime)
        }

        It 'Adds hours, minutes, seconds correctly' {
            $result = Convert-LocalToUTC $testTime -AddDays 1 -AddHours 2 -AddMinutes 3 -Verbose
            $expected = (Get-Date $testTime).AddDays(1).AddHours(2).AddMinutes(3)
            $result.LocalTime | Should Be $expected
        }

        It 'Returns the time when not verbose' {
            Mock -ModuleName LocalToUtc Invoke-GetTimeZone {
                return "Central Standard Time"
            }
            $result = Convert-LocalToUTC $testTime
            $expected = (Get-Date $testTime).AddHours(5)
            $result | Should Be $expected
        }
    }

    Context 'Parameters' {
        It 'Has the timezone as the first unnamed parameter' {
            $localTime = Get-Date $testTime
            $utc = (Get-Date $testTime).AddHours(4) # 4 hours ahead for EDT
            $result = Convert-LocalToUtc $localTime "Eastern Standard Time"
            $result | Should Be $utc
        }
    }

    Context 'Pipeline support' {
        It 'Converts pipeline value' {
            $result = (Get-Date $testTime) | Convert-LocalToUtc -TimeZone "Pacific Standard Time"
            $result | Should Be (Get-Date $testTime).AddHours(7)
        }

        It 'Converts named Time' {
            $local = Get-Date $testTime
            $obj = New-Object psobject -Property @{ Name = "hello"; Time=$local; SomeField=123456 }
            $result = $obj | Convert-LocalToUtc -TimeZone "Pacific Standard Time"
            $result | Should Be (Get-Date $testTime).AddHours(7)
        }
    }
}

Describe 'UtcToLocal' {
    $testTime= "2017-09-04 08:25:00"

    Context 'Time Conversion' {
        It 'Returns a time if no parameters are set' {
            $result = Convert-UtcToLocal
            $result | Should BeOfType [System.DateTime]
        }

        It 'Parses ISO8601 properly' {
            $result = Convert-UtcToLocal -Time $testTime -Verbose
            $expected = Get-Date $testTime
            $result.UtcTime | Should Be $expected
        }

        It 'Converts UTC time to local time correctly' {
            $result = Convert-UtcToLocal -Time $testTime -TimeZone "Eastern Standard Time"
            $expected = (Get-Date $testTime).AddHours(-4)
            $result | Should Be $expected
        }

        It 'Adds hours, minutes, seconds correclty' {
            $result = Convert-UtcToLocal $testTime "Eastern Standard Time" -AddDays 1 -AddHours 2 -AddMinutes 3 -Verbose
            $expected = (Get-Date $testTime).AddDays(1).AddHours(2).AddMinutes(3)
            $result.UtcTime | Should Be $expected
        }
    }

    Context 'Parameters' {
        It 'Has the timezone as the first unnamed parameter' {
            $utc = Get-Date $testTime
            $local = (Get-Date $testTime).AddHours(-4) # 4 hours behind for EDT
            $result = Convert-UtcToLocal $utc "Eastern Standard Time"
            $result | Should Be $local
        }
    }

    Context 'CmdletBinding Support' {
        It 'Verbose returns the full object' {
            $pst = Get-TimeZone "Pacific Standard Time"
            $result = Convert-UtcToLocal (Get-Date $testTime) "Pacific Standard Time" -Verbose
            $utc = Get-Date $testTime
            $local = $utc.AddHours(-7)
            $result.LocalTime | Should Be $local
            $result.UtcTime | Should Be $utc
            $result.TimeZone | Should Be $pst
        }
    }

    Context 'Pipeline Support' {
        It 'Converts pipeline value' {
            $result = (Get-Date $testTime) | Convert-UtcToLocal -TimeZone "Pacific Standard Time"
            $result | Should Be (Get-Date $testTime).AddHours(-7)
        }
        
        It 'Converts named Time' {
            $utc = Get-Date $testTime
            $obj = New-Object psobject -Property @{ Name = "hello"; Time=$utc; SomeField=123456 }
            $result = $obj | Convert-UtcToLocal -TimeZone "Pacific Standard Time"
            $result | Should Be (Get-Date $testTime).AddHours(-7)
        }
    }
}

Describe 'Convert-TimeZone' {
    # Accounting for Daylight savings
    $testTime= "2017-09-04 08:25:00"
    
    Context 'TimeZone Conversion' {
        It 'Converts time zones' {
            $result = Convert-TimeZone $testTime -ToTimeZone "Alaskan Standard Time" -FromTimeZone "Hawaiian Standard Time"
            $result | Should Be (Get-Date $testTime).AddHours(2)
        }

        It 'Uses local system time when not specified' {
            Mock -ModuleName LocalToUtc Invoke-GetTimeZone {
                return "Eastern Standard Time"
            }
            Mock -ModuleName LocalToUtc Get-UtcTime {
                return "2017-09-04 08:25:00"
            }
            $result = Convert-TimeZone -ToTimeZone "Pacific Standard Time"
            $result | Should Be (Get-Date $testTime).AddHours(-7)
        }
    }

    Context 'Verbose' {
        $cst = Get-Date $testTime
        $utc = $cst.AddHours(5)
        $japanTime = $utc.AddHours(9)

        # convert $testTime in Central Standard Time to Japan Standard Time
        $result = Convert-TimeZone $cst "Tokyo Standard Time" "Central Standard Time" -Verbose

        $result.Time | Should Be $cst
        $result.ToTime | Should Be $japanTime
        $result.FromTimeZone | Should Be (Get-TimeZone "Central Standard Time")
        $result.ToTimeZone | Should Be (Get-TimeZone "Tokyo Standard Time")
    }

    Context 'Pipeline Support' {
        It 'Converts pipeline time' {
            $time = Get-Date $testTime
            $result = $time | Convert-TimeZone -ToTimeZone "Pacific Standard Time" -FromTimeZone "Central Standard Time"
            $result | Should Be $time.AddHours(-2)
        }

        It 'Converts named Time' {
            $time = Get-Date $testTime
            $obj = New-Object psobject -Property @{ Name = "hello"; Time=$time; SomeField=123456 }
            $result = $obj | Convert-TimeZone -ToTimeZone "Pacific Standard Time" -FromTimeZone "Eastern Standard Time"
            $result | Should Be (Get-Date $testTime).AddHours(-3)
        }
    }

}
