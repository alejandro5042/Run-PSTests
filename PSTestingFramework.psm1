
# TODO: Do isolation per module.

function Assert-Fail 
{
    [System.Diagnostics.DebuggerStepThroughAttribute()]
    param($Message, [switch]$Continue)
    
    if ($Continue)
    {
        Write-Error $Message
    }
    else
    {
        throw $Message
    }
}

function Assert-True
{
    [System.Diagnostics.DebuggerStepThroughAttribute()]
    param($Condition, $Message, [switch]$Continue)
    if (!$condition)
    {
        $Message = "Assert-True Failed. $Message"
        Assert-Fail $Message -Continue:$Continue
    }
}

####################################################################################################

# $messages = @()

function Invoke-FunctionIfExists($Function, $AlternateFunction, [switch]$ThrowExceptions)
{
    try
    {
        if ($Function)
        {
            [void](& $Function @args)
        }
        elseif ($AlternateFunction)
        {
            [void](& $AlternateFunction @args)
        }    
    }
    catch
    {
        if ($ThrowExceptions)
        {
            throw $_
        }
        else
        {
            $_
        }
    }
}

function Run-Tests
{
    [CmdletBinding()]
    param
    (
        $Path = ".",
        
        [string]
        $Filter = "",
        
        [switch]
        $PassThru
    )
        
    foreach ($testModulePath in ls $Path -Recurse -Include *Tests.psm1 -Exclude "Run-PSTests.ps1")
    {
        try
        {
            $testModule = Import-Module $testModulePath -Force -PassThru -DisableNameChecking -Verbose:$false
            
            $beginTesting = $testModule.ExportedCommands["TestFramework-BeginTesting"]
            $endTesting = $testModule.ExportedCommands["TestFramework-EndTesting"]
            $runTest = $testModule.ExportedCommands["TestFramework-RunTest"]
            
            try
            {
                $tests = @(
                    $testModule.ExportedCommands.Values |
                    where Name -like "Test-*" |
                    where Name -match $Filter
                )
                
                Write-Verbose "Executing Module: $($testModule.Name)"
                Invoke-FunctionIfExists $beginTesting -ThrowExceptions
                
                $i = 0
                foreach ($test in $tests)
                {
                    $i += 1
                    
                    Write-Verbose "  - Test ($i/$($tests.Length)): $($test.Name)"
                    
                    [void]($test -match "--(.*)$")
                    $attributes = $Matches[1]
                    
                    $outcome = "Completed"
                    $passed = $true
                    $exception = $null
                    
                    $start = [DateTime]::Now
                    
                    if ($attributes -eq "Ignored")
                    {
                        $outcome = "Ignored"
                    }
                    else
                    {                    
                        $exception = Invoke-FunctionIfExists $runTest { & $args[0] } $test
                    }
                    
                    $end = [DateTime]::Now
                    
                    if ($exception)
                    {
                        Write-Verbose "    ** $($test.Name) Failed! **"
                        $outcome = "Exception"
                        $passed = $false
                    }
                    
                    [PSCustomObject]@{
                        Module = $testModule.Name;
                        Test = $test.Name;
                        Passed = $passed;
                        Outcome = $outcome;
                        Exception = $exception;
                        StartTime = $start;
                        EndTime = $end;
                        Duration = $end - $start
                    }
                }
            }
            finally
            {
                Invoke-FunctionIfExists $endTesting -ThrowExceptions
            }
        }
        finally
        {
            $testModule | Remove-Module -Force
        }
    }
}
