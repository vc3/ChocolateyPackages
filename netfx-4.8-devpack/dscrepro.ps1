$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
        }
    )
}
configuration NetFxDevPackCrashRepro
{
    Node localhost
    {
        Package pkg1
        {
            Name = '.NET Framework 4.8 Developer Pack'
            Path = 'C:\Install\NDP48-DevPack-ENU.exe'
            Arguments = '/Quiet /NoRestart'
            ProductId = ''
            #PsDscRunAsCredential = (Get-Credential -Credential "${Env:ComputerName}\userfordsc") # fails with this too
        }
    }
}
$ProgressPreference = 'SilentlyContinue'
New-Item -ItemType Directory -Path 'C:\Install'
Invoke-WebRequest -Uri 'https://download.microsoft.com/download/6/5/7/6577634A-8D5D-4558-BA22-A81CC6D5BB06/NDP48-DevPack-ENU.exe' -OutFile 'C:\Install\NDP48-DevPack-ENU.exe'
NetFxDevPackCrashRepro -OutputPath 'C:\Install' -ConfigurationData $cd
#Start-DscConfiguration -Path 'C:\Install' -ComputerName 'localhost' -Verbose -Wait -Force
