$version = "1.0.0 (2024-05-11)"

# load config from JSON file located in the same directory
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
$config = Get-Content -Path $configPath | ConvertFrom-Json

# parse config
# second prefix, after backup type ("instance" or "saves")
$globalPrefix = "$($config.packName)-$($config.packVersion)"
$instancePath = $config.instancePath
$destination = $config.destinationPath
$tempBasePath = $config.tempPath
$sevenZipPath = $config.sevenZipPath
$threads = $config.threads

# initialize paths for zip files, will be set on call to MakeBackup
$instanceZipPath = $null
$savesZipPath = $null

# performs backups by copying source via robocopy and then compressing via 7zip
function MakeBackup {
    param (
        [string]$sourcePath,        # source directory to backup
        [string]$destinationPath,   # destination directory, where zip will be created
        [string]$prefix,            # prefix for zip file name (type of backup: "instance" or "saves")
        [ref]$zipPath               # reference var to store path of created archive
    )

    # setup name/path of zip file to create with timestamp
    $date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $zipFilePath = "$destinationPath\$prefix-$globalPrefix-$date.zip"
    # store the path in this reference var
    $zipPath.Value = $zipFilePath

    # create destination directory if doesn't already exist
    if (-not (Test-Path -Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force
    }

    # create logs subdirectory in destination directory if doesn't already exist
    $logsDirPath = Join-Path -Path $destinationPath -ChildPath "ea-logs"
    if (-not (Test-Path -Path $logsDirPath)) {
        New-Item -ItemType Directory -Path $logsDirPath -Force
    }

    # make a temporary subdirectory inside the base temp path specified by config
    $tempPath = Join-Path -Path $tempBasePath -ChildPath "$prefix-$globalPrefix-$date"
    New-Item -ItemType Directory -Path $tempPath -Force

    Write-Host "[EnderArchiver]: Copying $prefix directory with robocopy..." -ForegroundColor Yellow

    # copy files from source to temporary directory using robocopy
    $robocopyLogPath = Join-Path -Path $logsDirPath -ChildPath ("ea-log-robocopy-$date.txt")
    robocopy $sourcePath $tempPath /MIR /COPY:DAT /R:5 /W:10 /MT:$threads /LOG:$robocopyLogPath
    if ($LASTEXITCODE -ne 1) {
        Write-Host "`n`n[EnderArchiver/ERROR]: Robocopy failed with exit code $LASTEXITCODE. Check log file for details: $robocopyLogPath" -ForegroundColor Red
        throw "`n`n[EnderArchiver/ERROR]: Robocopy failed with exit code $LASTEXITCODE. Check log file for details: $robocopyLogPath"
    }

    Write-Host "[EnderArchiver]: Robocopy successful" -ForegroundColor Yellow
    Write-Host "[EnderArchiver]: Compressing copy of $prefix directory with 7zip..." -ForegroundColor Yellow

    # compress the copied files into a zip archive using 7zip
    # compression level -mx=5 is about the same as what the GUI uses
    $arguments = "a -tzip `"$zipFilePath`" `"$tempPath\*`" -mx=5 -mmt=$threads"
    $process = Start-Process -FilePath $sevenZipPath -ArgumentList $arguments -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Host "`n`n[EnderArchiver/ERROR]: 7-Zip failed with exit code $($process.ExitCode)" -ForegroundColor Red
        throw "`n`n[EnderArchiver/ERROR]: 7-Zip failed with exit code $($process.ExitCode)"
    }

    Write-Host "[EnderArchiver]: Zip archive successfully created at: $zipFilePath" -ForegroundColor Yellow

    # remove the temporary directory
    Write-Host "[EnderArchiver]: Cleaning up temporary files..." -ForegroundColor Yellow
    Remove-Item -Path $tempPath -Recurse -Force
    Write-Host "[EnderArchiver]: Cleaned up temporary files" -ForegroundColor Yellow
}

try {
    Write-Host "[EnderArchiver]: EnderArchiver $version" -ForegroundColor Yellow

    # mark start time
    $startTime = Get-Date

    # backup instance directory
    Write-Host "[EnderArchiver]: Starting backup of instance directory..." -ForegroundColor Yellow
    MakeBackup -sourcePath $instancePath -destinationPath $destination -prefix "instance" -zipPath ([ref]$instanceZipPath)
    Write-Host "[EnderArchiver]: Instance backup complete" -ForegroundColor Yellow

    # backup saves directory
    Write-Host "[EnderArchiver]: Starting backup of saves directory..." -ForegroundColor Yellow
    $subSource = Join-Path -Path $instancePath -ChildPath "minecraft\saves"
    MakeBackup -sourcePath $subSource -destinationPath $destination -prefix "saves" -zipPath ([ref]$savesZipPath)
    Write-Host "[EnderArchiver]: Saves backup complete" -ForegroundColor Yellow

    # mark end time, calculate duration
    $endTime = Get-Date
    $duration = New-TimeSpan -Start $startTime -End $endTime
    Write-Host "`n`n[EnderArchiver]: Backup complete, took $($duration.Hours) hours $($duration.Minutes) minutes $($duration.Seconds) seconds" -ForegroundColor Green
    Write-Host "[EnderArchiver]: Files generated:"
    Write-Host $instanceZipPath
    Write-Host $savesZipPath
}
catch {
    Write-Host "`n`n[EnderArchiver/ERROR]: An error occurred: $_" -ForegroundColor Red
    exit 1
}
