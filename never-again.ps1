############################################
# setup config:

# delete git files
$deleteGit = $FALSE

# start .rbxl file on completion
$startRbxl = $TRUE

# open new project in vscode on completion
$openVSCode = $TRUE

# open new project in explorer on completion
$openExplorer = $FALSE

# remove integration files
$cleanInstall = $FALSE

# always npm install @quenty/servicebag
$installServiceBag = $TRUE

############################################

# query project options
$name = Read-Host "Project Name?"
$defaultInstallation = Read-Host "Default Installation? (Y/N)"
$otherPackages = Read-Host "Added Packaging? (format: '@author/name')
Denote packaging split via commas"

# default options
$name = $name.Trim().Replace(' ','-')
$defaultInstallation.Trim().ToUpper()

# installServiceBag
if ($installServiceBag -eq $TRUE) {
    $otherPackages = ("@quenty/servicebag,$otherPackages")
}
$otherPackages = $otherPackages.Trim().ToLower().Replace(' ', '').Split(',')

# post-default options
if ($name.Length -eq 0) { $name = "nevermore-project" }
if ($defaultInstallation -ne "Y") { $defaultInstallation = "N" }

# suffix $name incrementally until (Test-Path $name) -eq $TRUE
$increment = 0
do { if ((Test-Path $name) -eq $TRUE) { $increment++ } }
until (((Test-Path $name) -eq $FALSE) -or ((Test-path "$name-$increment") -eq $FALSE))
if ($increment -gt 0) { $name = "$name-$increment" }

try {
    # create directory 
    New-Item -Name $name -ItemType "directory"
    cd $name

    # clone *only* the NevermoreEngine repository's metadata and checkout
    # the games/integration directories - move the modules, scripts, and
    # package.json to our new root directory
    git clone --filter=blob:none --sparse "https://www.github.com/Quenty/NevermoreEngine"
    cd NevermoreEngine
    git sparse-checkout add games\integration
    cd games\integration

    Move-Item package.json ..\..\..

    #cleanInstall
    if ($cleanInstall -eq $TRUE) {
        Get-ChildItem -Include * -Exclude "default.project.json" -File -Recurse | ForEach {
            $_.Delete()
        }
    }

    Move-Item modules ..\..\..
    Move-Item scripts ..\..\..
    cd ..\..\..

    # convert our JSONs to a PSObjects so we can edit their contents
    $packages = Get-Content "package.json" | ConvertFrom-Json

    # in non-default mode, remove all dependencies from $packages
    $packageStrings = [PSCustomObject]@{}
    $otherPackages | ForEach {
        if ($_.Length -gt 0) {
            $packageStrings | Add-Member -MemberType "NoteProperty" -Name $_ -Value ""
        }
    }

    if ($defaultInstallation -eq "N") {
        $packages.PSObject.Properties.Remove("dependencies")
        $packages | Add-Member -MemberType "NoteProperty" -Name "dependencies" -Value $packageStrings
    } else {
        $otherPackages | ForEach {
            if ($_.Length -gt 0) {
                $packages.dependencies | Add-Member -MemberType "NoteProperty" -Name $_ -Value ""
            }
        }
    }

    $packages

    $packages = $packages | ConvertTo-Json
    Set-Content "package.json" $packages

    # install our packages
    npm install

    # initialize rojo
    rojo init

    # maintain the blank baseplate and remove project requirements
    $project = Get-Content "default.project.json" | ConvertFrom-Json
    $project.tree.PSObject.Properties | ForEach {
        if (-not (($_.Name -eq '$className') -or ($_.Name -eq 'Workspace'))) {
            $project.tree.PSObject.Properties.Remove($_.Name)
        }
    }
    $project = $project | ConvertTo-Json -Depth 6
    Set-Content "default.project.json" $project

    # build from our modified rojo file
    rojo build --output baseplate.rbxl
    Remove-Item "default.project.json" -Force

    # move our NevermoreEngine project file
    cd NevermoreEngine\games\integration
    Move-Item default.project.json ..\..\.. -Force
    cd ..\..\..

    $nevermoreProject = Get-Content "default.project.json" | ConvertFrom-Json
    $nevermoreProject.PSObject.Properties.Remove("name")
    $nevermoreProject | Add-Member -MemberType "NoteProperty" -Name "name" -Value $name
    $nevermoreProject = $nevermoreProject | ConvertTo-Json -Depth 6
    Set-Content "default.project.json" $nevermoreProject

    # remove unused directories and their files
    Remove-Item "src" -Force -Recurse
    Remove-Item "NevermoreEngine" -Force -Recurse

    # deleteGit
    if ($deleteGit -eq $TRUE) {
        Remove-Item .git -Force -Recurse
        Remove-Item .gitignore -Force -Recurse
        Remove-Item README.md -Force -Recurse
    }

    # startRbxl - start our game file
    if ($startRbxl -eq $TRUE) { start baseplate.rbxl }
    # openExplore - open explorer
    if ($openExplorer -eq $TRUE) { explorer . }
    # openVSCode - open VSCode
    if ($openVSCode -eq $TRUE) { code . }
} catch {
    Write-Error $_.Exception.ToString()
    Read-Host -Prompt "The above error occured. Press Enter to exit."
}