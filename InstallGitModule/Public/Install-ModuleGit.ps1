Set-StrictMode -Version Latest
# Sanity system for allowing these variables to not exist in powershell 5.1
if ($PSVersionTable.PSEdition -ne "Core") {
	$IsLinux = $false
	$IsOSX = $false
}
<#
	.Synopsis
	Installs a powershell module from a git repo
	
	.Description
	Will download a zip of a repo, then try to install it correctly to a location dependant on the position/presence of .psd1 files
	
	.Example
	This will install a powershell yaml module to the normal/non-admin user's powershell module directory.
	Install-ModuleGit -GitHubRepo Phil-Factor/PSYaml -DestinationPath C:\Users\vagrant\Documents\WindowsPowerShell\Modules
	
	.Outputs
	None.
	
	.Notes
	This function will default to trying to install to the admin's powershell, so if run as a normal user, the appropriate directory will need to be specified.
#>

function Install-ModuleGit {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        $GitHubRepo,
        $Branch = "master",
        [Parameter(ValueFromPipelineByPropertyName)]
        $ProjectUri,
		
		# The scope of module installation
		[ValidateSet('CurrentUser', 'AllUsers')]
		[String] $Scope = "AllUsers"
    )

    Process {
        if($PSBoundParameters.ContainsKey("ProjectUri")) {
            $GitHubRepo = $null
            if($ProjectUri.OriginalString.StartsWith("https://github.com")) {
                $GitHubRepo = $ProjectUri.AbsolutePath
            } else {
                $name=$ProjectUri.LocalPath.split('/')[-1]
                Write-Output ("Module [{0}]: not installed, it is not hosted on GitHub " -f $name)
            }
        }

        if($GitHubRepo) {
                Write-Verbose ("[$(Get-Date)] Retrieving {0} {1}" -f $GitHubRepo, $Branch)

                $url = "https://github.com/{0}/archive/{1}.zip" -f $GitHubRepo, $Branch
                $targetModuleName=$GitHubRepo.split('/')[-1]
                Write-Debug "targetModuleName: $targetModuleName"

                $tmpDir = [System.IO.Path]::GetTempPath()

                $OutFile = Join-Path -Path $tmpDir -ChildPath "$($targetModuleName).zip"
                Write-Debug "OutFile: $OutFile"


                if ($IsLinux -or $IsOSX) {
					Invoke-RestMethod $url -OutFile $OutFile
                }

                else {
					Invoke-RestMethod $url -OutFile $OutFile
					Unblock-File $OutFile
                }
				
				$outDirectory = New-Item -Path $tmpDir -Name $targetModuleName -ItemType "directory" -Force
                Expand-Archive -Path $OutFile -DestinationPath $outDirectory -Force
                Write-Debug "targetModule: $targetModuleName"
				
				if (Get-Module $targetModuleName) {
					Write-Debug "You already have this module loaded. Trying to unload."
					if (Get-ChildItem (Get-Module -ListAvailable $targetModuleName).ModuleBase -Recurse -Include *.dll) {
						Write-Debug "This module has a .dll and so thus can't be safely unloaded to be overwritten. You'll need to make sure you don't have it loaded before you attempt to install over it."	
						return
					}
					else {
						Write-Debug "Hopefully removed the problem."
						Remove-Module $targetModuleName
					}
				}
				
				if ($IsLinux -or $IsOSX) {
					$destPathArray = $env:PSModulePath.Split(":")
                }

                else {
					$destPathArray = $env:PSModulePath.Split("{;}")
                }
				
				# Selecting which scope we'll go for
				Write-Debug "Current value of -Scope: $Scope"
				if ($Scope -eq 'AllUsers') {
					$scopeDest = '\ProgramFiles\WindowsPowerShell\Modules'
				}
				else {
					$scopeDest = $HOME
				}
				Write-Debug "Current scope dest: $scopeDest" 
				
				foreach ($_ in $destPathArray) {
					if ($_.Contains($scopeDest)) {
						$dest = $_
						break
					}
				}
				Write-Debug "Current dest: $dest"
				
				$psd1Modules = @(Get-ChildItem -Path $outDirectory -Include *.psd1 -Recurse)
				
				foreach ($_ in $psd1Modules) {
					$moduleDest = Join-Path -Path $_.Name.split('.')[0] -ChildPath (Import-PowerShellDataFile $_.FullName).ModuleVersion
					$moduleDest = Join-Path -Path $dest -ChildPath $moduleDest
					if (Test-Path $moduleDest) { Remove-Item -Path $moduleDest -Recurse }
					Copy-Item $_.DirectoryName -Destination $moduleDest -Recurse -Force
				}
				
				$dest = Join-Path -Path $dest -ChildPath $targetModuleName
				Write-Debug "dest: $dest"
				
				if ($psd1Modules.Count -eq 0) {
					While ($outDirectory.GetDirectories().Length -eq 1 -and $outDirectory.GetFiles().Length -eq 0) {
						$outDirectory = (Get-ChildItem $outDirectory)
						if (Test-Path $dest) {
							Get-ChildItem -Path $dest -Recurse | Remove-Item -Recurse -Force
							Remove-Item $dest -Force
						}
						Copy-Item -Path $outDirectory.FullName -Destination $dest -Force -Recurse
					}
				}
				
        }
    }
}
