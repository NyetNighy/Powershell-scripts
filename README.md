# PowerShell Scripts

General-purpose PowerShell scripts for Microsoft 365 administration — Exchange Online, Azure AD/Entra, SharePoint, Teams, Intune, password management, Active Directory, and general tooling.

---

## 📂 Folder Structure

### `M365-Exchange/` — Exchange Online Administration
| Script | Purpose |
|--------|---------|
| `AliasFinder.ps1` | Search all Exchange recipients (incl. soft-deleted) for an email alias |
| `BlockProfilePictures365.ps1` | Create and apply no-photo OWA mailbox policy to all licensed users |
| `OnlyAcceptFromPermNew.ps1` | Restrict M365 group email to approved senders only |
| `PurgeEmailBySubject.ps1` | Purge emails by subject line (Compliance search) |
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
| `Recover deleted OneDrive.txt` | Steps to recover a deleted OneDrive |
| `Studentfoldercreation.ps1` | Bulk-create student folder structures in SharePoint from CSV |

### `M365-Teams/` — Microsoft Teams Administration
| Script | Purpose |
|--------|---------|
| `TEAMSDATA.ps1` | Extract Teams data and membership via Graph |
| `Disable Teams automatically being added to calendar..txt` | Disable Teams auto-adding meetings to calendar |

### `M365-Email/` — Email Configuration & Audit
| Script | Purpose |
|--------|---------|
| `Allow or block list on 365.txt` | Tenant allow/block sender lists in Exchange Online |
| `External message allow..txt` | Configure external sender allow list in Exchange Online |
| `Find email alias.txt` | Find which recipient an email alias belongs to |
| `Run-MailboxAuditLogSearcher.ps1` | Search mailbox audit logs |
| `Powershell Exchange mem list.txt` | Export distribution list members |

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
| `bulk update 365 passwords.txt` | Bulk reset M365 passwords from CSV |
| `ForceChangePassword All users 365.txt` | Force all M365 users to change password on next logon |
| `set one 365 user to not have password expiry.txt` | Disable password expiry for a single user |
| `Atomwide LGFL password reset.txt` | Reset Atomwide/LGFL user passwords |
| `Atomwide LGFL password reset CSV.txt` | Bulk reset Atomwide passwords from CSV |
| `Azure connect for Atomwide PW reset.ps1` | Connect to Azure AD for Atomwide password resets |

### `Active-Directory/` — On-Premises AD Administration
| Script | Purpose |
|--------|---------|
| `BitlockerCount.ps1` | Count active BitLocker-enabled computers (last logon ≤1 year) |
| `DetectBitlockerPIN.ps1` | Detect if BitLocker TPM+PIN protector is configured |
| `UsersNon-Log1Year.ps1` | Find enabled AD users with no login in ≥1 year |

### `Security-Admin/` — Security, Audit & Hardening
| Script | Purpose |
|--------|---------|
| `ExportSignLogs.ps1` | Export full M365 sign-in audit logs via Graph |
| `FastStartUpDisable.ps1` | Disable Windows Fast Startup via registry |

### `General-Reference/` — Docs, Notes & Reference Material
| File | Purpose |
|------|---------|
| `4.8net.ps1` | .NET 4.8 network configuration |
| `DGSG.txt` | Azure AD group type conversion notes |
| `Emaildisable.ps1` | Disable email for mailbox |
| `Firewall Intune.txt` | Intune firewall endpoint references |
| `Remote search and uninstall..txt` | Remote uninstall reference |
| `SNMP error #-2003.txt` | SNMP error troubleshooting note |
| `tls.txt` | TLS configuration guide |
| `Whitelist.txt` | SharePoint/exchange whitelist reference |
| `sharepoint connect..txt` | SharePoint connection commands |

### `General-Tools/` — Cross-Category Utilities
| Script | Purpose |
|--------|---------|
| `ME5024_Disks.ps1` | PRTG custom sensor for Dell PowerVault ME5024 storage array |
| `replace.ps1` | Fix curly quotes in PowerShell files |

---

## 🏷️ Tags

`#m365` `#exchange` `#azure-ad` `#sharepoint` `#onedrive` `#microsoft-teams` `#intune` `#active-directory` `#security` `#audit` `#email` `#powershell`

---

## 📋 Requirements

- **Exchange Online** scripts → `ExchangeOnlineManagement` module v3.9.0+
- **Microsoft Graph** scripts → `Microsoft.Graph` and `Microsoft.Graph.Beta`
- **SharePoint/PnP** scripts → `PnP.PowerShell`
- **Active Directory** scripts → RSAT AD module on Windows
- All scripts tested on **Windows PowerShell 5.1** or **PowerShell 7+**