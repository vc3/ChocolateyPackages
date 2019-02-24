. (Join-Path -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition) -ChildPath 'helpers.ps1')

$packageName = 'netfx-4.7.1-devpack'
$version = '4.7.1'
$productNameWithVersion = "Microsoft .NET Framework $version Developer Pack"
$url = 'https://download.microsoft.com/download/9/0/1/901B684B-659E-4CBD-BEC8-B3F06967C2E7/NDP471-DevPack-ENU.exe'
$checksum = 'A615488D2C5229AFF3B97C56F7E5519CC7AC4F58B638A8E159B19C5C3D455C7B'
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
    fileType = 'exe'
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
            $installResult.ExitCode = $ERROR_SUCCESS # to avoid triggering failure detection in choco.exe
        }
        else
        {
            Write-Verbose "mscorlib.dll not found in expected location: $mscorlibPath"
            Write-Verbose 'This probably means the installer crashed before it could fully install the devpack'
        }
    }
}

Invoke-CommandWithTempPath -TempPath $safeLogPath -ScriptBlock { Install-ChocolateyInstallPackageAndHandleExitCode @installerExeArguments -ExitCodeHandler $exitCodeHandler }
