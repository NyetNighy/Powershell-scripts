# PowerShell Scripts

A collection of PowerShell scripts for Microsoft 365, Entra ID, Exchange Online, SharePoint, Teams, Intune, Active Directory, and security administration.

| Extension | Description |
|-----------|-------------|
| `.ps1` | Runnable, parameterized scripts |
| `.txt` | Runbooks and notes — command sequences for reference, not production scripts |

---

## Safety

Several scripts perform irreversible or high-impact changes (mailbox purge, password reset, sign-in disable, directory sync disable).

- Interactive scripts prompt for input, display a summary, and require explicit confirmation before applying changes.
- Prefer scoped searches and review item counts before confirming destructive actions.
- Test in a non-production tenant where possible.
- Use the Graph-based scripts under `M365-Passwords/`; avoid legacy MSOnline or AzureAD module one-liners.

---

## Repository structure

### [CSVs/](CSVs/)

Sample CSV templates for scripts that accept file input. See [CSVs/README.md](CSVs/README.md) and [CSV column requirements](#csv-column-requirements).

### M365-Exchange/

| Script | Description |
|--------|-------------|
| `AddFullPermissionToMailbox.ps1` | Grant Full Access (optional AutoMapping) to one user across multiple mailboxes |
| `AliasFinder.ps1` | Search all Exchange recipients, including soft-deleted, for an email alias |
| `BlockProfilePictures365.ps1` | Create and apply a no-photo OWA mailbox policy |
| `OnlyAcceptFromPermNew.ps1` | Restrict Microsoft 365 group email to approved senders |
| `PurgeEmailFromAndSubjectUpdated.ps1` | Purge messages by sender and/or subject via Compliance search (SoftDelete or HardDelete) |

### M365-Azure/

| Script | Description |
|--------|-------------|
| `AddCsvUsersToGroup365.ps1` | Add users from a CSV to an existing Microsoft 365 or Security group |
| `AddOwnerToEmptyM365Groups.ps1` | Locate Microsoft 365 groups with no members or owners and assign the signed-in Global Admin |
| `BlockSignInFromCsv.ps1` | Disable sign-in for users listed in a CSV (Microsoft Graph) |
| `Check-All-M365-Objects.ps1` | Report and optionally convert directory-synced groups and mailboxes |
| `DisableADSYNClink365.ps1` | Disable Azure AD Connect sync via Graph |
| `DisableADSYNClink365New.ps1` | Disable Azure AD Connect sync in the cloud and optionally stop the server service |
| `Member365Transfer.ps1` | Copy members between Microsoft 365 groups |
| `Register-PnPEntraIDAppForInteractiv.ps1` | Register a PnP Entra ID application for interactive Graph authentication |
| `UserMembershipReport.ps1` | Export user membership, licence, and department data |

### M365-SharePoint/

| Script | Description |
|--------|-------------|
| `OneDriveRegionalSettings.ps1` | Bulk-set OneDrive regional settings (admin URL, locale, timezone) |
| `RegionalOneDrive.ps1` | Regional OneDrive settings via PnP (prefer `OneDriveRegionalSettings.ps1`) |
| `RegionalOneDriveBlank.ps1` | Template version of the regional settings script |
| `Onedrive.ps1` | General OneDrive management tasks |
| `Recover deleted OneDrive.txt` | Runbook — recover a deleted OneDrive |
| `Studentfoldercreation.ps1` | Create student folder structures in SharePoint from a CSV |

### M365-Teams/

| Script | Description |
|--------|-------------|
| `TEAMSDATA.ps1` | Extract Teams data and membership via Microsoft Graph |
| `Disable Teams automatically being added to calendar..txt` | Runbook — disable automatic calendar integration |

### M365-Email/

| Script | Description |
|--------|-------------|
| `Allow or block list on 365.txt` | Runbook — tenant allow/block sender lists |
| `External message allow..txt` | Runbook — external sender allow list |
| `Find email alias.txt` | Runbook — resolve an alias to a recipient |
| `Run-MailboxAuditLogSearcher.ps1` | Search mailbox audit logs |
| `Powershell Exchange mem list.txt` | Runbook — export distribution list members |

### M365-Devices/

| Script | Description |
|--------|-------------|
| `CountDevices.ps1` | Count managed Intune devices |
| `devicecount.ps1` | Device count variant |
| `GetOfficeVer.ps1` | Office version report from Active Directory computers |
| `WindowsVersionAD.ps1` | Windows version and build report for AD computers |

### M365-Passwords/

| Script | Description |
|--------|-------------|
| `BulkUpdatePasswords.ps1` | Bulk-set passwords from a CSV (Graph; preview and confirm) |
| `ForceChangePasswordAllUsers.ps1` | Force password change at next sign-in (all, licensed, or single user) |
| `DisablePasswordExpiry.ps1` | Disable password expiration for a single user |

### Active-Directory/

| Script | Description |
|--------|-------------|
| `BitlockerCount.ps1` | Count BitLocker-enabled computers with recent logon |
| `DetectBitlockerPIN.ps1` | Detect TPM+PIN BitLocker protectors |
| `UsersNon-Log1Year.ps1` | Find enabled AD users with no logon in the past year |

### Security-Admin/

| Script | Description |
|--------|-------------|
| `ExportSignLogs.ps1` | Export Microsoft 365 sign-in audit logs via Graph |
| `Analyse-SignInsAbroad.ps1` | Analyse a sign-in CSV for successful authentication from outside the UK |
| `Export-And-Analyse-SignIns.ps1` | Export sign-in logs and analyse for non-UK successful access in a single run |
| `FastStartUpDisable.ps1` | Disable Windows Fast Startup via registry |

### General-Reference/

| File | Description |
|------|-------------|
| `4.8net.ps1` | .NET Framework 4.8 network configuration |
| `DGSG.txt` | Notes — Azure AD group type conversion |
| `Remote search and uninstall..txt` | Notes — remote uninstall reference |
| `tls.txt` | Notes — TLS configuration |
| `Whitelist.txt` | Notes — SharePoint/Exchange whitelist |
| `sharepoint connect..txt` | Notes — SharePoint connection commands |

### General-Tools/

| Script | Description |
|--------|-------------|
| `ME5024_Disks.ps1` | PRTG custom sensor for Dell PowerVault ME5024 |
| `replace.ps1` | Replace curly quotes in PowerShell source files |
| `ShortcutDesktop.ps1` | Create a public desktop shortcut for PaperCut Print Deploy Client |

---

## CSV column requirements

Scripts that accept CSV input require a header row. Column names are matched case-insensitively where noted. Extra columns are ignored. Empty rows and blank identity cells are skipped.

Sample templates are available in [CSVs/](CSVs/).

| Script | Required columns | Alternate names | Notes |
|--------|------------------|-----------------|-------|
| `BulkUpdatePasswords.ps1` | Identity, password | Identity: `UserPrincipalName`, `UPN`, `Mail`, `Email` · Password: `Password`, `NewPassword`, `Pwd` | Preview of first 10 rows; optional force-change at next sign-in |
| `AddCsvUsersToGroup365.ps1` | Identity | `UserPrincipalName`, `Mail`, `Email`, `UPN` | Resolves by UPN then mail; duplicates removed |
| `BlockSignInFromCsv.ps1` | Identity | `UserPrincipalName`, `UPN`, `Mail`, `Email`, `EmailAddress` | Sets `AccountEnabled = false` |
| `Studentfoldercreation.ps1` | `Surname`, forename | Forename: `Forname` or `Forename` | Creates folders named `Surname, Forename` |

### Example CSV formats

**Bulk password update**

```csv
UserPrincipalName,Password
jane.doe@contoso.com,TempP@ssw0rd1!
john.smith@contoso.com,TempP@ssw0rd2!
```

**Add users to a group**

```csv
UserPrincipalName
jane.doe@contoso.com
john.smith@contoso.com
```

**Block sign-in**

```csv
Email
jane.doe@contoso.com
john.smith@contoso.com
```

**Student folders**

```csv
Surname,Forename
Doe,Jane
Smith,John
```

---

## Requirements

| Area | Module / dependency |
|------|---------------------|
| Exchange Online | `ExchangeOnlineManagement` 3.9.0+ |
| Microsoft Graph | `Microsoft.Graph`, `Microsoft.Graph.Users`, `Microsoft.Graph.Groups` |
| SharePoint / PnP | `PnP.PowerShell` |
| Active Directory | RSAT Active Directory module (Windows) |
| Runtime | Windows PowerShell 5.1 or PowerShell 7+ |

---

## Usage examples

### Sign-in log export and analysis

```powershell
# Export sign-in logs
.\Security-Admin\ExportSignLogs.ps1
.\Security-Admin\ExportSignLogs.ps1 -OutputPath D:\Reports\signins.csv

# Analyse an existing CSV for successful sign-ins from outside the UK
# File picker for input; Save dialog for output (timestamp always appended)
.\Security-Admin\Analyse-SignInsAbroad.ps1
.\Security-Admin\Analyse-SignInsAbroad.ps1 -InputFile "C:\Downloads\InteractiveSignIns.csv"

# Export and analyse in one operation
.\Security-Admin\Export-And-Analyse-SignIns.ps1
```

`Analyse-SignInsAbroad.ps1` accepts:

- Entra portal Interactive Sign-ins CSV exports (including files with duplicate column headers)
- CSV output produced by `ExportSignLogs.ps1`

### CSV-driven scripts

```powershell
.\M365-Passwords\BulkUpdatePasswords.ps1
.\M365-Azure\AddCsvUsersToGroup365.ps1
.\M365-Azure\BlockSignInFromCsv.ps1
.\M365-SharePoint\Studentfoldercreation.ps1
```

Each script prompts for the CSV path at runtime. Sample files are in [CSVs/](CSVs/).

---

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for script standards, folder placement, and the pull request process.

---

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behaviour to the repository maintainer.

---

## Licence

MIT — see [LICENSE](LICENSE).
