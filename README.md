![logo](assets/logo.svg)

# EnderArchiver
A PowerShell script to automate modded MC instance backups.

## Requirements
- [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows): 5.0 or later
- [7-Zip](https://www.7-zip.org/): Tested on 23.01 (2023-06-20)

## Configuration
Configure the script in `config.json`, which must be in the same directory as the script:
- `packName`: Name of your modpack
- `packVersion`: Version of your modpack
- `instancePath`: Path to your instance directory
- `destinationPath`: Path to where backup files are stored
- `sevenZipPath`: Path to where 7-Zip is installed
- `threads`: Number of threads to use for file copying and compression

If on Windows, you can find how many threads your computer has with the command-line utility `WMIC`:
```powershell
WMIC cpu get numberofLogicalProcessors
```
An example configuration file:

```json
{
    "packName": "atm9",
    "packVersion": "0.2.58",
    "instancePath": "C:\\Users\\user\\AppData\\Roaming\\PrismLauncher\\instances\\All the Mods 9 - ATM9",
    "destinationPath": "D:\\backup\\mc\\atm9",
    "sevenZipPath": "C:\\Program Files\\7-Zip\\7z.exe",
    "threads": 8
}
```

## Running the script
Execute the PowerShell script by running:
```powershell
powershell .\EnderArchiver.ps1
```
If running scripts is disabled, you can temporarily bypass this by running:
```powershell
powershell -ExecutionPolicy Bypass -File .\EnderArchiver.ps1
```

Alternatively, you can run the provided batch file, `ea-wrapper.bat`, or [change your execution policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies).

## Outputs
The script will make a backup of your `instancePath` directory and the `saves` subdirectory, in this format:
- Instance backup: `instance-packName-packVersion-yyyy-MM-dd_HH-mm-ss.zip`
- Saves backup: `saves-packName-packVersion-yyyy-MM-dd_HH-mm-ss.zip`
> [!NOTE]
> The script assumes your saves directory is in: `instancePath\minecraft\saves`

In the same directory as the script, log files and temporary files are generated in folders named `ea-logs` and `ea-temp`, respectively.

## Troubleshooting
- Ensure all paths in `config.json` are correct and accessible
- Ensure you have permission to read and write to the source and destination directories
- Review the `robocopy` log generated in the same directory as the executed script
