. (Join-Path -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition) -ChildPath 'helpers.ps1')

$packageName = 'netfx-4.8-devpack'
$version = '4.8'
$productNameWithVersion = "Microsoft .NET Framework $version Developer Pack early access build 3745"
$url = 'https://download.visualstudio.microsoft.com/download/pr/9854b5f2-2341-4136-ad7d-1d881ab8d603/e3a011f2a41a59b086f78d64e1c7a3fc/NDP48-DevPack-ENU.exe'
$checksum = '67979C8FBA2CD244712A31A7FE323FD8BD69AA7971F152F8233CB109A7260F06'
$checksumType = 'sha256'

$originalFileName = Split-Path -Leaf -Path ([uri]$url).LocalPath
$downloadFilePath = Get-DefaultChocolateyLocalFilePath -OriginalFileName $originalFileName
$downloadArguments = @{
    packageName = $packageName
    fileFullPath = $downloadFilePath
    url = $url
    checksum = $checksum
    checksumType = $checksumType
    url64 = $url
    checksum64 = $checksum
    checksumType64 = $checksumType
}

Get-ChocolateyWebFile @downloadArguments | Out-Null

$accessViolationCode = 0xC0000005
$safeLogPath = Get-SafeLogPath
$installerExeArguments = @{
    packageName = $packageName
    file = $downloadFilePath
    silentArgs = ('/Quiet /NoRestart /Log "{0}\{1}_{2}_{3:yyyyMMddHHmmss}.log"' -f $safeLogPath, $packageName, $version, (Get-Date))
    validExitCodes = @(
        0 # success
        3010 # success, restart required
        $accessViolationCode # installer crash (access violation), but may occur at the very end, after the devpack is installed
    )
}

Invoke-CommandWithTempPath -TempPath $safeLogPath -ScriptBlock { Install-ChocolateyInstallPackage @installerExeArguments }

Write-Warning "ChocolateyExitCode: ${Env:ChocolateyExitCode}"
if ($Env:ChocolateyExitCode -eq '3010')
{
    Write-Warning "A restart is required to finalize $productNameWithVersion installation."
}
elseif ($Env:ChocolateyExitCode -eq $accessViolationCode)
{
    $mscorlibPath = "${Env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\v${version}\mscorlib.dll"
    Write-Warning "The native installer crashed, checking if it managed to install the devpack before the crash"
    if (Test-Path -Path $mscorlibPath)
    {
        Write-Warning "mscorlib.dll found: $mscorlibPath"
        Write-Warning 'This probably means the devpack got installed successfully, despite the installer crash'
    }
    else
    {
        Write-Warning "mscorlib.dll not found in expected location: $mscorlibPath"
        Write-Warning 'This probably means the installer crashed before it could fully install the devpack'
        throw "The native devpack installer crashed with code 0x$($accessViolationCode.ToString('X'))"
    }
}
else
{
    Write-Warning "NOT 3010 or $accessViolationCode"
    if ($Env:ChocolateyExitCode -eq $null)
    {
        Write-Host "A restart may be required to finalize $productNameWithVersion installation."
    }
}
