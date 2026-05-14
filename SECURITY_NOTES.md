# ⚠️ Security & Sensitive Data Notes

> **Do not share or publish this repo publicly without first sanitising the files listed below.**

---

## 🔴 Tenant / Organisation Identifying Information

### BCTec Ltd — Hardcoded in Multiple Scripts

| File | Exposure |
|------|----------|
| `Register-PnPEntraIDAppForInteractiv.ps1` | Tenant: `bctec.onmicrosoft.com` |
| `OneDriveRegionalSettings.ps1` | Admin URL: `https://bcteccouk-admin.sharepoint.com/` |
| `RegionalOneDrive.ps1` | Admin URL: `https://bcteccouk-admin.sharepoint.com` + UPN: `BCTecLtd@bcteccouk.onmicrosoft.com` + Client ID: `23cccbe2-78f8-4659-8c4e-d7f828df07d4` |

### Second Organisation

| File | Exposure |
|------|----------|
| `Studentfoldercreation.ps1` | Tenant: `meadowfieldschool.onmicrosoft.com` — appears to be a school (PupilFiles, student CSV) |

---

## 🟡 Customer/Client Data References

| File | Exposure |
|------|----------|
| `PurgeEmailFromandSubject.ps1` | Search name contains: `PurgeAbbeyGazetteEmail` — suggests a client called "Abbey Gazette" |
| `PurgeEmailFromAndSubject.ps1` | Same `PurgeAbbeyGazetteEmail` reference |
| `PurgeEmailFromAndSubjectUpdated.ps1` | Same `PurgeAbbeyGazetteEmail` reference |
| `PurgeFromSubDisWAM.ps1` | Same `PurgeAbbeyGazetteEmail` reference |

---

## 🟢 Credential / Secret Patterns (Not Currently Active)

These scripts contain placeholder values that look like credentials but are clearly marked as template/example values. They are **not currently active** but should still be sanitised before publishing:

| File | Pattern |
|------|---------|
| `ME5024_Disks.ps1` | `YOUR_API_USERNAME`, `YOUR_API_PASSWORD` — placeholder, no real creds |
| `RegionalOneDriveBlank.ps1` | `YOURTENANT-admin.sharepoint.com`, `YOUR-CLIENT-ID`, `365AdminUser` — clearly template |
| `replace.ps1` | References `C:\Powershell\ExportSignLogs1m.ps1` — hardcoded local path |

---

## 📋 Required Sanitisation Steps

1. **Remove hardcoded tenant references** — `bctec.onmicrosoft.com`, `bcteccouk-admin.sharepoint.com`, `meadowfieldschool.onmicrosoft.com`
2. **Remove the Azure AD client ID** — `23cccbe2-78f8-4659-8c4e-d7f828df07d4` in `RegionalOneDrive.ps1`
3. **Remove the "Abbey Gazette" client reference** — from PurgeEmail purge script names/comments
4. **Consider redacting admin UPN** — `BCTecLtd@bcteccouk.onmicrosoft.com` in `RegionalOneDrive.ps1`
5. **Remove the hardcoded SharePoint admin URL** in `OneDriveRegionalSettings.ps1`

---

*Last reviewed: 2026-05-14 by Ori*