$version = "1.2.0 (2024-05-13)"

# load config from JSON file located in the same directory
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
$config = Get-Content -Path $configPath | ConvertFrom-Json

# parse config
# second prefix, after backup type ("instance" or "saves")
$packPrefix = "$($config.packName)-$($config.packVersion)"
$instancePath = $config.instancePath
$destination = $config.destinationPath
$sevenZipPath = $config.sevenZipPath
$threads = $config.threads

# initialize paths for zip files, will be set on call to MakeBackup
$instanceZipPath = $null
$savesZipPath = $null

# create temp folder named 'ea-temp' where script was ran if doesn't already exist
$eaTempPath = Join-Path -Path $PSScriptRoot -ChildPath "ea-temp"
if (-not (Test-Path -Path $eaTempPath)) {
    New-Item -ItemType Directory -Path $eaTempPath -Force
}

# create logs folder named 'ea-logs' where script was ran if doesn't already exist
$eaLogsPath = Join-Path -Path $PSScriptRoot -ChildPath "ea-logs"
if (-not (Test-Path -Path $eaLogsPath)) {
    New-Item -ItemType Directory -Path $eaLogsPath -Force
}

# performs backups by copying source via robocopy and then compressing via 7zip
function MakeBackup {
    param (
        # source directory to backup    
        [string]$sourcePath,
        # destination directory, where zip will be created
        [string]$destinationPath,
        # prefix for zip file name (type of backup: "instance" or "saves")
        [string]$prefix,
        # reference var to store path of created archive
        [ref]$zipPath
    )

    # setup name/path of zip file to create with timestamp
    $date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $zipFilePath = Join-Path -Path $destinationPath -ChildPath "$prefix-$packPrefix-$date.zip"
    # store the path in this reference var
    $zipPath.Value = $zipFilePath

    # create destination directory if doesn't already exist
    if (-not (Test-Path -Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force
    }

    # this path is inside the ea-temp folder, where for each backup, one temporary
    # folder will be created with a unique name containing the files for that backup
    $tempPath = Join-Path -Path $eaTempPath -ChildPath "$prefix-$packPrefix-$date"
    New-Item -ItemType Directory -Path $tempPath -Force

    Write-Host "[EnderArchiver]: Copying $prefix directory with robocopy..." -ForegroundColor Yellow

    # path for an individual log file
    $robocopyLogPath = Join-Path -Path $eaLogsPath -ChildPath ("ea-log-robocopy-$date.txt")
    # copy files from source to temporary directory using robocopy
    robocopy $sourcePath $tempPath /MIR /COPY:DAT /R:5 /W:10 /MT:$threads /LOG:$robocopyLogPath
    if ($LASTEXITCODE -ne 1) {
        Write-Host "`n`n[EnderArchiver/ERROR]: Robocopy failed with exit code $LASTEXITCODE. Check log file for details: $robocopyLogPath" -ForegroundColor Red
        throw "`n`n[EnderArchiver/ERROR]: Robocopy failed with exit code $LASTEXITCODE. Check log file for details: $robocopyLogPath"
    }

    Write-Host "[EnderArchiver]: Robocopy successful" -ForegroundColor Yellow
    Write-Host "[EnderArchiver]: Compressing copy of $prefix directory with 7zip..." -ForegroundColor Yellow

    # compress the copied files into a zip archive using 7zip
    # compression level -mx=5 is about the same as what the GUI uses
    $tempPathWildcard = Join-Path -Path $tempPath -ChildPath "*"
    $arguments = "a -tzip `"$zipFilePath`" `"$tempPathWildcard`" -mx=5 -mmt=$threads"
    $process = Start-Process -FilePath $sevenZipPath -ArgumentList $arguments -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Host "`n`n[EnderArchiver/ERROR]: 7-Zip failed with exit code $($process.ExitCode)" -ForegroundColor Red
        throw "`n`n[EnderArchiver/ERROR]: 7-Zip failed with exit code $($process.ExitCode)"
    }

    Write-Host "[EnderArchiver]: Zip archive successfully created at: $zipFilePath" -ForegroundColor Yellow
}

try {
    Write-Host "[EnderArchiver]: EnderArchiver $version" -ForegroundColor Yellow

    $startTime = Get-Date

    # backup instance directory
    Write-Host "[EnderArchiver]: Starting backup of instance directory..." -ForegroundColor Yellow
    MakeBackup -sourcePath $instancePath -destinationPath $destination -prefix "instance" -zipPath ([ref]$instanceZipPath)
    Write-Host "[EnderArchiver]: Instance backup complete" -ForegroundColor Yellow

    # navigate to instance/minecraft/saves
    $mcDirPath = Join-Path -Path $instancePath -ChildPath "minecraft"
    $savesDirPath = Join-Path -Path $mcDirPath -ChildPath "saves"

    # backup saves directory
    Write-Host "[EnderArchiver]: Starting backup of saves directory..." -ForegroundColor Yellow
    MakeBackup -sourcePath $savesDirPath -destinationPath $destination -prefix "saves" -zipPath ([ref]$savesZipPath)
    Write-Host "[EnderArchiver]: Saves backup complete" -ForegroundColor Yellow

    $endTime = Get-Date
    $duration = New-TimeSpan -Start $startTime -End $endTime

    Write-Host "`n`n[EnderArchiver]: Backup complete, took $($duration.Hours) hours $($duration.Minutes) minutes $($duration.Seconds) seconds" -ForegroundColor Green
    Write-Host "[EnderArchiver]: Files generated:"
    Write-Host $instanceZipPath
    Write-Host $savesZipPath
}
catch {
    Write-Host "`n`n[EnderArchiver/ERROR]: An error occurred: $_" -ForegroundColor Red
}
finally {
    # remove ea-temp if exists
    if (Test-Path -Path $eaTempPath) {
        Write-Host "`n[EnderArchiver]: Cleaning up temporary files..." -ForegroundColor Yellow
        Remove-Item -Path $eaTempPath -Recurse -Force
        Write-Host "[EnderArchiver]: Cleaned up temporary files" -ForegroundColor Yellow
    }
}
