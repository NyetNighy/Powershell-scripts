# PowerShell Scripts

General-purpose PowerShell scripts for Microsoft 365 administration — Exchange Online, Azure AD/Entra, SharePoint, Teams, Intune, password management, Active Directory, and general tooling.

**File types**

| Extension | Meaning |
|-----------|---------|
| `.ps1` | Runnable PowerShell script (prefer these) |
| `.txt` | **Runbook / notes** — copy-paste command sequences, not parameterized scripts. Treat as documentation until converted. |

---

## Safety for destructive operations

Scripts that **purge mail**, **reset passwords**, or **force password change** can permanently alter a tenant.

- Purge scripts require typing **`YES`** before HardDelete (see `PurgeEmailBySubject.ps1`).
- Prefer a scoped search + review of item counts before confirming.
- Run in a lab tenant first when testing.
- Password-related `.txt` runbooks under `M365-Passwords/` are high-impact; convert to parameterized `.ps1` with `-WhatIf` before production use.

---

## 📂 Folder Structure

### `M365-Exchange/` — Exchange Online Administration
| Script | Purpose |
|--------|---------|
| `AliasFinder.ps1` | Search all Exchange recipients (incl. soft-deleted) for an email alias |
| `BlockProfilePictures365.ps1` | Create and apply no-photo OWA mailbox policy to all licensed users |
| `OnlyAcceptFromPermNew.ps1` | Restrict M365 group email to approved senders only |
| `PurgeEmailBySubject.ps1` | Purge emails by subject (Compliance search; requires **YES** confirm) |
| `PurgeEmailByToAndSubject.ps1` | Purge emails by recipient + subject |
| `PurgeEmailFromUpdated.ps1` | Purge emails by From address only |
| `PurgeEmailFromUserLog.ps1` | Purge emails with audit logging |
| `PurgeFromSubDisWAM.ps1` | Purge emails from sub-distribution groups via WAM |

### `M365-Azure/` — Azure AD / Microsoft Graph / Entra ID
| Script | Purpose |
|--------|---------|
| `Check-All-M365-Objects.ps1` | Check all M365 users/groups for directory sync status, convert cloud-only |
| `DisableADSYNClink365.ps1` | Disable Azure AD Connect sync via Graph API |
| `DisableADSYNClink365New.ps1` | Disable AAD Connect sync (module-based, admin-checked) |
| `Member365Transfer.ps1` | Transfer members between M365 groups by ID |
| `Register-PnPEntraIDAppForInteractiv.ps1` | Register a PnP Entra ID app for interactive Graph login |
| `UserMembershipReport.ps1` | Full user membership/license/department report across Azure AD |

### `M365-SharePoint/` — SharePoint & OneDrive Administration
| Script | Purpose |
|--------|---------|
| `OneDriveRegionalSettings.ps1` | Bulk-set OneDrive regional settings (locale + timezone) for all users |
| `RegionalOneDrive.ps1` | Regional OneDrive settings via PnP |
| `RegionalOneDriveBlank.ps1` | Template version of the above |
| `Onedrive.ps1` | OneDrive management tasks |
| `Recover deleted OneDrive.txt` | **Runbook** — steps to recover a deleted OneDrive |
| `Studentfoldercreation.ps1` | Bulk-create student folder structures in SharePoint from CSV |

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
| `bulk update 365 passwords.txt` | **Runbook** — bulk reset M365 passwords from CSV |
| `ForceChangePassword All users 365.txt` | **Runbook** — force password change on next logon |
| `set one 365 user to not have password expiry.txt` | **Runbook** — disable password expiry for one user |
| `Atomwide LGFL password reset.txt` | **Runbook** — org-specific password reset |
| `Atomwide LGFL password reset CSV.txt` | **Runbook** — bulk org-specific reset from CSV |
| `Azure connect for Atomwide PW reset.ps1` | Connect to Azure AD for password resets |

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
| `Emaildisable.ps1` | Disable email for mailbox |
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

---

## 📋 Requirements

- **Exchange Online** scripts → `ExchangeOnlineManagement` module v3.9.0+
- **Microsoft Graph** scripts → `Microsoft.Graph` / `Microsoft.Graph.Reports` (sign-in export)
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

---

## 🏷️ Tags

`#m365` `#exchange` `#azure-ad` `#sharepoint` `#onedrive` `#microsoft-teams` `#intune` `#active-directory` `#security` `#audit` `#email` `#powershell`

## License

MIT — see [LICENSE](LICENSE).
