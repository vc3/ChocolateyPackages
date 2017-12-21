function Remove-VSNegatedPackageParameters
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)] [hashtable] $PackageParameters,
        [switch] $RemoveNegativeSwitches
    )

    # --no-foo cancels --foo
    $negativeSwitches = $PackageParameters.GetEnumerator() | Where-Object { $_.Key -match '^no-.' -and $_.Value -eq '' } | Select-Object -ExpandProperty Key
    foreach ($negativeSwitch in $negativeSwitches)
    {
        if ($negativeSwitch -eq $null)
        {
            continue
        }

        $parameterToRemove = $negativeSwitch.Substring(3)
        if ($PackageParameters.ContainsKey($parameterToRemove))
        {
            Write-Debug "Removing negated package parameter: '$parameterToRemove'"
            $PackageParameters.Remove($parameterToRemove)
        }

        if ($RemoveNegativeSwitches)
        {
            Write-Debug "Removing negative switch: '$negativeSwitch'"
            $PackageParameters.Remove($negativeSwitch)
        }
    }
}
