<#
    These tests should only be run in AppVeyor since the second half of the tests require
    the AppVeyor administrator account credential to run.

    Also please note that some of these tests depend on each other.
    They must be run in the order given - if one test fails, subsequent tests may
    also fail.
#>

if ($PSVersionTable.PSVersion.Major -lt 5 -or $PSVersionTable.PSVersion.Minor -lt 1)
{
    Write-Warning -Message 'Cannot run PSDscResources integration tests on PowerShell versions lower than 5.1'
    return
}

$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$script:testFolderPath = Split-Path -Path $PSScriptRoot -Parent
$script:testHelpersPath = Join-Path -Path $script:testFolderPath -ChildPath 'TestHelpers'
Import-Module -Name (Join-Path -Path $script:testHelpersPath -ChildPath 'CommonTestHelper.psm1')

$script:testEnvironment = Enter-DscResourceTestEnvironment `
    -DscResourceModuleName 'PSDscResources' `
    -DscResourceName 'MSFT_WindowsProcess' `
    -TestType 'Integration'

try
{
    $script:testProcessPath = Join-Path -Path $script:testHelpersPath -ChildPath 'WindowsProcessTestProcess.exe'
    $script:logFilePath = Join-Path -Path $script:testHelpersPath -ChildPath 'processTestLog.txt'
    $script:configFile = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_WindowsProcess.config.ps1'

    Describe 'WindowsProcess Integration Tests without Credential' {
        Context 'Should stop any current instances of the testProcess running' {
            $configurationName = 'MSFT_WindowsProcess_Setup'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Absent' `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }
            
            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Absent'
            }

            It 'Should not create a logfile' {
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $false
            }
        }

        Context 'Should start a new testProcess instance as running' {
            $configurationName = 'MSFT_WindowsProcess_StartProcess'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            $logFileCreated = New-Object -TypeName 'System.Threading.EventWaitHandle' `
                                         -ArgumentList @($false,
                                                        [System.Threading.EventResetMode]::ManualReset,
                                                        'LogFileIntegrationTest.LogFileCreated')
            $null = $logFileCreated.Reset()

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Present' `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }
       
            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Present'
                $currentConfig.ProcessCount | Should Be 1
            }

            It 'Should create a logfile' {
                # Wait for the process to finish writing to the log file.
                $logFileCreated.WaitOne(10000)
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $true
                Remove-Item -Path $script:logFilePath
            }
        }

        Context 'Should not start a second new testProcess instance when one is already running' {
            $configurationName = 'MSFT_WindowsProcess_StartSecondProcess'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Present' `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }
       
            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Present'
                $currentConfig.ProcessCount | Should Be 1
            }

            It 'Should not create a logfile' {
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $false
            }
        }

        Context 'Should stop the testProcess instance from running' {
            $configurationName = 'MSFT_WindowsProcess_StopProcesses'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Absent' `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }
       
            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Absent'
            }

            It 'Should not create a logfile' {
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $false
            }
        }

        Context 'Should return correct amount of processes running when more than 1 are running' {
            $configurationName = 'MSFT_WindowsProcess_StartMultipleProcesses'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            $logFileCreated = New-Object -TypeName 'System.Threading.EventWaitHandle' `
                                         -ArgumentList @($false,
                                                        [System.Threading.EventResetMode]::ManualReset,
                                                        'LogFileIntegrationTest.LogFileCreated')
            $null = $logFileCreated.Reset()

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Present' `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should start another process running' {
                Start-Process -FilePath $script:testProcessPath -ArgumentList @($script:logFilePath)
            }
       
            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Present'
                $currentConfig.ProcessCount | Should Be 2
            }

            It 'Should create a logfile' {
                # Wait for the process to finish writing to the log file.
                $logFileCreated.WaitOne(10000)
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $true
                Remove-Item -Path $script:logFilePath
            }
        }

        Context 'Should stop all of the testProcess instances from running' {
            $configurationName = 'MSFT_WindowsProcess_StopAllProcesses'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Absent' `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }
       
            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Absent'
            }

            It 'Should not create a logfile' {
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $false
            }
        }
    }
    
    Describe 'WindowsProcess Integration Tests with Credential' {
        $script:configData = @{
            AllNodes = @(
                @{
                    NodeName = '*'
                    PSDscAllowPlainTextPassword = $true
                }
                @{
                    NodeName = 'localhost'
                }
            )
        }

        $script:testCredential = Get-AppVeyorAdministratorCredential

        $script:configFile = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_WindowsProcessWithCredential.config.ps1'

        Context 'Should stop any current instances of the testProcess running' {
            $configurationName = 'MSFT_WindowsProcess_SetupWithCredential'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Absent' `
                                         -Credential $script:testCredential `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath `
                                         -ConfigurationData $script:configData
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Absent'
            }

            It 'Should not create a logfile' {
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $false
            }
        }
        
        Context 'Should start a new testProcess instance as running' {
            $configurationName = 'MSFT_WindowsProcess_StartProcessWithCredential'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            $logFileCreated = New-Object -TypeName 'System.Threading.EventWaitHandle' `
                                         -ArgumentList @($false,
                                                        [System.Threading.EventResetMode]::ManualReset,
                                                        'LogFileIntegrationTest.LogFileCreated')
            $null = $logFileCreated.Reset()

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Present' `
                                         -Credential $script:testCredential `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath `
                                         -ConfigurationData $script:configData
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Present'
                $currentConfig.ProcessCount | Should Be 1
            }

            It 'Should create a logfile' {
                # Wait for the process to finish writing to the log file.
                $logFileCreated.WaitOne(10000)
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $true
                Remove-Item -Path $script:logFilePath
            }
        }

        Context 'Should not start a second new testProcess instance when one is already running' {
            $configurationName = 'MSFT_WindowsProcess_StartSecondProcessWithCredential'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Present' `
                                         -Credential $script:testCredential `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath `
                                         -ConfigurationData $script:configData
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }
       
            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Present'
                $currentConfig.ProcessCount | Should Be 1
            }

            It 'Should not create a logfile' {
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $false
            }
        }

        Context 'Should stop the testProcess instance from running' {
            $configurationName = 'MSFT_WindowsProcess_StopProcessesWithCredential'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Absent' `
                                         -Credential $script:testCredential `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath `
                                         -ConfigurationData $script:configData
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }
       
            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Absent'
            }

            It 'Should not create a logfile' {
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $false
            }
        }

        Context 'Should return correct amount of processes running when more than 1 are running' {
            $configurationName = 'MSFT_WindowsProcess_StartMultipleProcessesWithCredential'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            $logFileCreated = New-Object -TypeName 'System.Threading.EventWaitHandle' `
                                         -ArgumentList @($false,
                                                        [System.Threading.EventResetMode]::ManualReset,
                                                        'LogFileIntegrationTest.LogFileCreated')
            $null = $logFileCreated.Reset()

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Present' `
                                         -ErrorAction 'Stop' `
                                         -Credential $script:testCredential `
                                         -OutputPath $configurationPath `
                                         -ConfigurationData $script:configData
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should start another process running' {
                Start-Process -FilePath $script:testProcessPath -ArgumentList @($script:logFilePath)
            }
       
            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Present'
                $currentConfig.ProcessCount | Should Be 2
            }

            It 'Should create a logfile' {
                # Wait for the process to finish writing to the log file.
                $logFileCreated.WaitOne(10000)
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $true
                Remove-Item -Path $script:logFilePath
            }
        }

        Context 'Should stop all of the testProcess instances from running' {
            $configurationName = 'MSFT_WindowsProcess_StopAllProcessesWithCredential'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            if (Test-Path -Path $script:logFilePath)
            {
                Remove-Item -Path $script:logFilePath
            }

            It 'Should compile without throwing' {
                {
                    .$script:configFile -ConfigurationName $configurationName
                    & $configurationName -Path $script:testProcessPath `
                                         -Arguments $script:logFilePath `
                                         -Ensure 'Absent' `
                                         -Credential $script:testCredential `
                                         -ErrorAction 'Stop' `
                                         -OutputPath $configurationPath `
                                         -ConfigurationData $script:configData
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }
       
            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }

            It 'Should return the correct configuration' {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Path | Should Be $script:testProcessPath
                $currentConfig.Arguments | Should Be $script:logFilePath
                $currentConfig.Ensure | Should Be 'Absent'
            }

            It 'Should not create a logfile' {
                $pathResult = Test-Path $script:logFilePath
                $pathResult | Should Be $false
            }
        }
    }
}
finally
{
    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
}
