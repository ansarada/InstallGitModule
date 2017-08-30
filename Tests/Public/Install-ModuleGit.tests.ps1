$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Since we match the src/tests structure we can assume:
$here = $here -replace 'tests', 'InstallGitModule'

. "$here\$sut"

Describe "Public/Install-ModuleGit" {
	
	It "Github URL does not exist" {
		{ Install-ModuleGit -GitHubRepo Its-a/Fake } | Should Throw
	}
	
}