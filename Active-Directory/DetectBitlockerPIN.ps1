# Detect if a TPM + PIN protector already exists on the system drive.
# Exit 0 = present; exit 1 = not present or error.

try {
    if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        Write-Output "Get-BitLockerVolume not available (BitLocker module / admin rights required)"
        exit 1
    }

    $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop

    if ($volume.KeyProtector | Where-Object {
            $_.KeyProtectorType -eq 'TpmPin' -or $_.KeyProtectorType -eq 'TpmAndPin'
        }) {
        Write-Output "BitLocker PIN protector is present"
        exit 0
    }
    else {
        Write-Output "BitLocker PIN protector is not present"
        exit 1
    }
}
catch {
    Write-Output "Error checking BitLocker: $($_.Exception.Message)"
    exit 1
}
