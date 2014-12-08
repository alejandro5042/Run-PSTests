
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

function Invoke-FunctionIfExists($Function, $AlternateFunction)
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
        $_
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
            Remove-Module $testModulePath -Force -ErrorAction SilentlyContinue
            $testModule = Import-Module $testModulePath -PassThru -DisableNameChecking -Verbose:$false
            
            $beginTesting = $testModule.ExportedCommands["TestFramework-BeginTesting"]
            $endTesting = $testModule.ExportedCommands["TestFramework-EndTesting"]
            $runTest = $testModule.ExportedCommands["TestFramework-RunTest"]
            
            try
            {
                $tests = @($testModule.ExportedCommands.Values | where Name -like "Test-*" | where Name -match $Filter)
                
                Write-Verbose "Executing Module: $($testModule.Name)"
                Invoke-FunctionIfExists $beginTesting
                
                $i = 0
                foreach ($test in $tests)
                {
                    $i += 1
                    
                    Write-Verbose "  - Test ($i/$($tests.Length)): $($test.Name)"
                    
                    $start = [DateTime]::Now
                    $error = Invoke-FunctionIfExists $runTest { & $args[0] } $test
                    $duration = [DateTime]::Now - $start
                    
                    if ($error)
                    {
                        Write-Verbose "    ** $($test.Name) Failed! **"
                    }
                    
                    $result = [PSCustomObject]@{
                        Module = $testModule.Name;
                        Test = $test.Name;
                        Error = $error;
                        Duration = $duration
                    }
                    
                    $result | Add-Member ScriptProperty Passed { $this.Error -eq $null }
                    $result
                }
            }
            finally
            {
                Invoke-FunctionIfExists $endTesting
            }
        }
        finally
        {
            Remove-Module $testModulePath -ErrorAction SilentlyContinue
        }
    }
}
