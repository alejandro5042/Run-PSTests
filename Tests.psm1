
function TestFramework-RunTest ($Test)
{
    Write-Host "hi!"
    [void](& $Test)
}

function Test-GoodMath
{
    Assert-True (2+2 -eq 4)
}

function Test-BadMath
{
    Assert-True (0+2 -eq 3)
}