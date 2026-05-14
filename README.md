# PowerShell Scripts

General-purpose PowerShell scripts for Microsoft 365 administration, Exchange Online, Azure AD, SharePoint/OneDrive, Active Directory, and security tooling.

> ⚠️ **Sensitive data notice** — Several scripts contain hardcoded tenant/admin credentials or identifying details. See [SECURITY_NOTES.md](./SECURITY_NOTES.md) before sharing or publishing.

---

## 📂 Folder Structure

### `M365-Exchange/` — Exchange Online & Email Administration
| Script | Purpose |
|--------|---------|
| `AliasFinder.ps1` | Search all Exchange recipients (incl. soft-deleted) for a given email alias |
| `BlockPhotos2.ps1` | Disable profile photo changes via OWA mailbox policy |
| `BlockProfilePictures365.ps1` | Create and apply no-photo OWA mailbox policy to all licensed users |
| `OnlyAcceptFromPerm.ps1` / `OnlyAcceptFromPermNew.ps1` | Restrict M365 group email to come from approved senders only |
| `PurgeEmailBySubject.ps1` | Purge emails from Exchange Online by subject line (Compliance search) |
| `PurgeEmailByToAndSubject.ps1` | Purge emails by recipient + subject |
| `PurgeEmailFromandSubject.ps1` | Purge emails by From address + subject |
| `PurgeEmailFromAndSubject.ps1` | Purge emails by From + subject (variant) |
| `PurgeEmailFromAndSubjectUpdated.ps1` | Updated version of From+subject purge |
| `PurgeEmailFromUpdated.ps1` | Purge emails by From address only |
| `PurgeEmailFromUserLog.ps1` | Purge emails with audit logging |
| `PurgeFromSubDisWAM.ps1` | Purge emails from sub-distribution groups via WAM |

### `M365-Azure/` — Azure AD / Microsoft Graph / Entra ID
| Script | Purpose |
|--------|---------|
| `Check-All-M365-Objects.ps1` | Check all M365 users/groups for on-premises directory sync status and convert cloud-only |
| `DisableADSYNClink365.ps1` | Disable Azure AD Connect sync via Graph API (direct) |
| `DisableADSYNClink365New.ps1` | Disable AAD Connect sync (module-based, with admin check) |
| `GroupMemberCopy.ps1` | Copy all members from one AD group to another |
| `Member365Transfer.ps1` | Transfer members between M365 groups by ID |
| `Register-PnPEntraIDAppForInteractiv.ps1` | Register a PnP Entra ID app for interactive Graph login |

### `M365-SharePoint/` — SharePoint & OneDrive Administration
| Script | Purpose |
|--------|---------|
| `OneDriveRegionalSettings.ps1` | Bulk-set OneDrive regional settings (locale + timezone) for all users |
| `RegionalOneDrive.ps1` | Regional OneDrive settings via PnP (configured for BCTec tenant) |
| `RegionalOneDriveBlank.ps1` | Template version of above — generic/placeholder values |
| `Studentfoldercreation.ps1` | Bulk-create student folder structures in SharePoint from CSV |

### `Active-Directory/` — On-Premises AD Administration
| Script | Purpose |
|--------|---------|
| `BitlockerCount.ps1` | Count active BitLocker-enabled computers in AD (last logon ≤1 year) |
| `DetectBitlockerPIN.ps1` | Detect if BitLocker TPM+PIN protector is configured |
| `GroupMemberCopy.ps1` | Copy AD group members between groups |
| `UsersNon-Log1Year.ps1` | Find enabled AD users with no login in ≥1 year |

### `Security-Admin/` — Security, Audit & Hardening
| Script | Purpose |
|--------|---------|
| `ExportSignLogs.ps1` | Export full Microsoft 365 sign-in audit logs via Graph |
| `FastStartUpDisable.ps1` | Disable Windows Fast Startup (hybrid boot) via registry |

### `Email-Purge/` — Dedicated Email Purge Scripts
| Script | Purpose |
|--------|---------|
| `PurgeEmailBySubject.ps1` | Purge by subject |
| `PurgeEmailByToAndSubject.ps1` | Purge by recipient + subject |
| `PurgeEmailFromandSubject.ps1` | Purge by From + subject |
| `PurgeEmailFromAndSubject.ps1` | Purge by From + subject (variant) |
| `PurgeEmailFromAndSubjectUpdated.ps1` | Updated variant |
| `PurgeEmailFromUpdated.ps1` | Purge by From only |
| `PurgeEmailFromUserLog.ps1` | Purge with logging |
| `PurgeFromSubDisWAM.ps1` | Purge via sub-distribution WAM |

### `General-Tools/` — Cross-Category / Utility Scripts
| Script | Purpose |
|--------|---------|
| `ME5024_Disks.ps1` | PRTG custom sensor for Dell PowerVault ME5024 storage array (REST API) |
| `replace.ps1` | Fix curly quotes in PowerShell files (utility) |

---

## 🏷️ Tags

`#m365` `#exchange` `#azure-ad` `#sharepoint` `#onedrive` `#active-directory` `#security` `#audit` `#email` `#powershell`

---

## 📋 Requirements

- **Exchange Online** scripts → `ExchangeOnlineManagement` module v3.9.0+
- **Microsoft Graph** scripts → `Microsoft.Graph` and `Microsoft.Graph.Beta`
- **SharePoint/PnP** scripts → `SharePointPnPPowerShellOnline` or `PnP.PowerShell`
- **Active Directory** scripts → RSAT AD module on Windows
- All scripts tested on **Windows PowerShell 5.1** or **PowerShell 7+**

---

## ⚠️ Credentials & Sensitive Data

See [SECURITY_NOTES.md](./SECURITY_NOTES.md) — some scripts contain hardcoded tenant names, admin UPNs, client IDs, or other identifying information. **Do not share or publish without reviewing and sanitising those files first.**