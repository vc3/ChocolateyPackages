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

$ERROR_SUCCESS = 0
$ERROR_SUCCESS_REBOOT_REQUIRED = 3010
$STATUS_ACCESS_VIOLATION = 0xC0000005

$safeLogPath = Get-SafeLogPath
$installerExeArguments = @{
    packageName = $packageName
    file = $downloadFilePath
    silentArgs = ('/Quiet /NoRestart /Log "{0}\{1}_{2}_{3:yyyyMMddHHmmss}.log"' -f $safeLogPath, $packageName, $version, (Get-Date))
    validExitCodes = @(
        $ERROR_SUCCESS # success
        $ERROR_SUCCESS_REBOOT_REQUIRED # success, restart required
    )
}

$exitCodeHandler = {
    $installResult = $_
    $exitCode = $installResult.ExitCode
    if ($exitCode -eq $ERROR_SUCCESS_REBOOT_REQUIRED)
    {
        Write-Warning "$productNameWithVersion has been installed, but a reboot is required to finalize the installation. Until the computer is rebooted, dependent packages may fail to install or function properly."
    }
    elseif ($exitCode -eq $ERROR_SUCCESS)
    {
        Write-Verbose "$productNameWithVersion has been installed successfully, a reboot is not required."
    }
    elseif ($exitCode -eq $null)
    {
        Write-Warning "Package installation has finished, but this Chocolatey version does not provide the installer exit code. A restart may be required to finalize $productNameWithVersion installation."
    }
    elseif ($exitCode -eq $STATUS_ACCESS_VIOLATION)
    {
        # installer crash (access violation), but may occur at the very end, after the devpack is installed
        if (Test-Path -Path 'Env:\ProgramFiles(x86)')
        {
            $programFiles32 = ${Env:ProgramFiles(x86)}
        }
        else
        {
            $programFiles32 = ${Env:ProgramFiles}
        }

        $mscorlibPath = "$programFiles32\Reference Assemblies\Microsoft\Framework\.NETFramework\v${version}\mscorlib.dll"
        Write-Warning "The native installer crashed, checking if it managed to install the devpack before the crash"
        Write-Debug "Testing existence of $mscorlibPath"
        if (Test-Path -Path $mscorlibPath)
        {
            Write-Verbose "mscorlib.dll found: $mscorlibPath"
            Write-Verbose 'This probably means the devpack got installed successfully, despite the installer crash'
            $installResult.ShouldFailInstallation = $false
        }
        else
        {
            Write-Verbose "mscorlib.dll not found in expected location: $mscorlibPath"
            Write-Verbose 'This probably means the installer crashed before it could fully install the devpack'
        }
    }
}

Invoke-CommandWithTempPath -TempPath $safeLogPath -ScriptBlock { Install-ChocolateyInstallPackageAndHandleExitCode @installerExeArguments -ExitCodeHandler $exitCodeHandler }
