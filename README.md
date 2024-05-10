# EnderArchiver
A PowerShell script to automate modded MC instance backups.

## Requirements
- **PowerShell**: 5.0 or later

## Configuration
Configure the script in `config.json`, which must be in the same directory as the script:
- `instancePath`: Path to your instance directory
- `destinationPath`: Path to where backup files are stored
- `packName`: Name of your modpack
- `packVersion`: Version of your modpack
> [!NOTE]
> The script assumes your saves directory is in: `instance\minecraft\saves`

## Running the script
Execute the PowerShell script by running:
```powershell
.\EnderArchiver.ps1
```

## Outputs
The script will make a backup of your `instancePath` directory and the `saves` subdirectory, in this format:
- Instance backup: `packName-packVersion-instance-yyyy-MM-dd_HH-mm-ss.zip`
- Saves backup: `packName-packVersion-saves-yyyy-MM-dd_HH-mm-ss.zip`

## Troubleshooting
- Ensure all paths in `config.json` are correct and accessible
- Ensure you have permission to read and write to the source and destination directories
- Review the `robocopy` log generated in the same directory as the executed script
