# PowerShell Scripts

General-purpose PowerShell scripts for Microsoft 365 administration — Exchange Online, Azure AD/Entra, SharePoint, Teams, Intune, password management, Active Directory, and general tooling.

**File types**

| Extension | Meaning |
|-----------|---------|
| `.ps1` | Runnable PowerShell script (prefer these) |
| `.txt` | **Runbook / notes** — copy-paste command sequences, not parameterized scripts. Treat as documentation until converted. |

---

## Safety for destructive operations

Scripts that **purge mail**, **reset passwords**, **disable sign-in**, **disable directory sync**, or **force password change** can permanently alter a tenant.

- Interactive scripts prompt for inputs, show a summary, and require **Y/N** confirmation before changes.
- The purge script (`PurgeEmailFromAndSubjectUpdated.ps1`) requires explicit confirmation before SoftDelete or HardDelete.
- Prefer a scoped search + review of item counts before confirming.
- Run in a lab tenant first when testing.
- Prefer the `.ps1` password scripts under `M365-Passwords/` (Microsoft Graph); do not use old MSOnline/AzureAD one-liners.

---

## 📂 Folder Structure

### `M365-Exchange/` — Exchange Online Administration
| Script | Purpose |
|--------|---------|
| `AddFullPermissionToMailbox.ps1` | Grant Full Access (with optional AutoMapping) to one user on multiple mailboxes |
| `AliasFinder.ps1` | Search all Exchange recipients (incl. soft-deleted) for an email alias |
| `BlockProfilePictures365.ps1` | Create/apply no-photo OWA policy (all licensed or single mailbox; confirms first) |
| `OnlyAcceptFromPermNew.ps1` | Restrict M365 group email to approved senders (prompts + confirms) |
| `PurgeEmailFromAndSubjectUpdated.ps1` | Purge emails by From and/or subject (Compliance search; SoftDelete or HardDelete) |

### `M365-Azure/` — Azure AD / Microsoft Graph / Entra ID
| Script | Purpose |
|--------|---------|
| `AddCsvUsersToGroup365.ps1` | Add users from a CSV (UPN/Mail/Email) to an existing M365 or Security group by Object ID |
| `BlockSignInFromCsv.ps1` | Disable sign-in for users listed in a CSV (Graph; replaces old AzureAD Emaildisable) |
| `Check-All-M365-Objects.ps1` | Optional sync disable + report/convert dir-synced groups/mailboxes (all steps confirmed) |
| `DisableADSYNClink365.ps1` | Disable Azure AD Connect sync via Graph (confirmation required) |
| `DisableADSYNClink365New.ps1` | Disable AAD Connect sync cloud + optional server stop (confirmation required) |
| `Member365Transfer.ps1` | Copy members between M365 groups by ID (count + confirm) |
| `Register-PnPEntraIDAppForInteractiv.ps1` | Register a PnP Entra ID app for interactive Graph login |
| `UserMembershipReport.ps1` | Full user membership/license/department report across Azure AD |

### `M365-SharePoint/` — SharePoint & OneDrive Administration
| Script | Purpose |
|--------|---------|
| `OneDriveRegionalSettings.ps1` | Bulk-set OneDrive regional settings (prompts for admin URL, locale, timezone) |
| `RegionalOneDrive.ps1` | Regional OneDrive settings via PnP (still has placeholders — prefer OneDriveRegionalSettings.ps1) |
| `RegionalOneDriveBlank.ps1` | Template version of the above |
| `Onedrive.ps1` | OneDrive management tasks |
| `Recover deleted OneDrive.txt` | **Runbook** — steps to recover a deleted OneDrive |
| `Studentfoldercreation.ps1` | Bulk-create student folder structures in SharePoint from CSV (all paths prompted) |

### `M365-Teams/` — Microsoft Teams Administration
| Script | Purpose |
|--------|---------|
| `TEAMSDATA.ps1` | Extract Teams data and membership via Graph |
| `Disable Teams automatically being added to calendar..txt` | **Runbook** — disable Teams auto-adding meetings to calendar |

### `M365-Email/` — Email Configuration & Audit
| Script | Purpose |
|--------|---------|
| `Allow or block list on 365.txt` | **Runbook** — tenant allow/block sender lists |
| `External message allow..txt` | **Runbook** — external sender allow list |
| `Find email alias.txt` | **Runbook** — find recipient for an alias |
| `Run-MailboxAuditLogSearcher.ps1` | Search mailbox audit logs |
| `Powershell Exchange mem list.txt` | **Runbook** — export distribution list members |

### `M365-Devices/` — Intune / Device Management
| Script | Purpose |
|--------|---------|
| `CountDevices.ps1` | Count managed Intune devices |
| `devicecount.ps1` | Count devices (variant) |
| `GetOfficeVer.ps1` | Get Office version report from AD computers |
| `WindowsVersionAD.ps1` | Windows version/build report for all AD computers |

### `M365-Passwords/` — Password Management
| Script | Purpose |
|--------|---------|
| `BulkUpdatePasswords.ps1` | Bulk-set passwords from CSV (Graph; preview + confirm) |
| `ForceChangePasswordAllUsers.ps1` | Force password change at next sign-in (all / licensed / single; confirm) |
| `DisablePasswordExpiry.ps1` | Disable password expiration for one user (Graph; confirm) |

### `Active-Directory/` — On-Premises AD Administration
| Script | Purpose |
|--------|---------|
| `BitlockerCount.ps1` | Count active BitLocker-enabled computers (last logon ≤1 year) |
| `DetectBitlockerPIN.ps1` | Detect if BitLocker TPM+PIN protector is configured |
| `UsersNon-Log1Year.ps1` | Find enabled AD users with no login in ≥1 year |

### `Security-Admin/` — Security, Audit & Hardening
| Script | Purpose |
|--------|---------|
| `ExportSignLogs.ps1` | Export full M365 sign-in audit logs via Graph (`-OutputPath` optional) |
| `FastStartUpDisable.ps1` | Disable Windows Fast Startup via registry |

### `General-Reference/` — Docs, Notes & Reference Material
| File | Purpose |
|------|---------|
| `4.8net.ps1` | .NET 4.8 network configuration |
| `DGSG.txt` | **Notes** — Azure AD group type conversion |
| `Firewall Intune.txt` | **Notes** — Intune firewall endpoints |
| `Remote search and uninstall..txt` | **Notes** — remote uninstall reference |
| `SNMP error #-2003.txt` | **Notes** — SNMP troubleshooting |
| `tls.txt` | **Notes** — TLS configuration |
| `Whitelist.txt` | **Notes** — SharePoint/Exchange whitelist |
| `sharepoint connect..txt` | **Notes** — SharePoint connection commands |

### `General-Tools/` — Cross-Category Utilities
| Script | Purpose |
|--------|---------|
| `ME5024_Disks.ps1` | PRTG custom sensor for Dell PowerVault ME5024 storage array |
| `replace.ps1` | Fix curly quotes in PowerShell files |
| `ShortcutDesktop.ps1` | Create a public desktop shortcut for PaperCut Print Deploy Client |

---

## 📋 Requirements

- **Exchange Online** scripts → `ExchangeOnlineManagement` module v3.9.0+
- **Microsoft Graph** scripts → `Microsoft.Graph` / `Microsoft.Graph.Users` / `Microsoft.Graph.Groups` (password, group, and sign-in scripts)
- **SharePoint/PnP** scripts → `PnP.PowerShell`
- **Active Directory** scripts → RSAT AD module on Windows
- Tested on **Windows PowerShell 5.1** or **PowerShell 7+**

### ExportSignLogs example

```powershell
# Default: CSV in current directory
.\Security-Admin\ExportSignLogs.ps1

# Custom path
.\Security-Admin\ExportSignLogs.ps1 -OutputPath D:\Reports\signins.csv
```

### Bulk password reset (CSV)

CSV columns: `UserPrincipalName` (or `UPN`/`Mail`/`Email`) and `Password` (or `NewPassword`).

```powershell
.\M365-Passwords\BulkUpdatePasswords.ps1
```

---

## 🏷️ Tags

`#m365` `#exchange` `#azure-ad` `#sharepoint` `#onedrive` `#microsoft-teams` `#intune` `#active-directory` `#security` `#audit` `#email` `#powershell`

## License

MIT — see [LICENSE](LICENSE).
