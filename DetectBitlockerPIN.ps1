# Detect if a TPM + PIN protector already exists
$volume = Get-BitLockerVolume -MountPoint $env:SystemDrive

if ($volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'TpmPin' -or $_.KeyProtectorType -eq 'TpmAndPin' }) {
    Write-Output "BitLocker PIN protector is present"
    exit 0
} else {
    exit 1
}