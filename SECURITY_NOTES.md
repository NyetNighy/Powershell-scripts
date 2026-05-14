# ⚠️ Security & Sensitive Data Notes

> All sensitive tenant, client, and credential data has been **sanitised** — replaced with placeholder values. Review any new scripts added to this repo before publishing.

---

## ✅ Sanitised Items (Already Fixed)

The following were hardcoded in the original commit and have been replaced with generic placeholders:

| File | Was | Now |
|------|-----|-----|
| `Register-PnPEntraIDAppForInteractiv.ps1` | `bctec.onmicrosoft.com` | `YOUR_TENANT.onmicrosoft.com` |
| `OneDriveRegionalSettings.ps1` | `https://bcteccouk-admin.sharepoint.com/` | `https://YOUR_TENANT-admin.sharepoint.com/` |
| `RegionalOneDrive.ps1` | `bcteccouk-admin.sharepoint.com` | `YOUR_TENANT-admin.sharepoint.com` |
| `RegionalOneDrive.ps1` | `23cccbe2-78f8-4659-8c4e-d7f828df07d4` | `YOUR_AZURE_AD_APP_CLIENT_ID` |
| `RegionalOneDrive.ps1` | `BCTecLtd@...` | `admin@YOUR_TENANT.onmicrosoft.com` |
| `Studentfoldercreation.ps1` | `meadowfieldschool.onmicrosoft.com` | `YOUR_TENANT.onmicrosoft.com` |
| `PurgeEmailFromandSubject.ps1` | `PurgeAbbeyGazetteEmail` | `PurgeClientEmail` |
| `PurgeEmailFromAndSubjectUpdated.ps1` | `PurgeAbbeyGazetteEmail` | `PurgeClientEmail` |
| `PurgeFromSubDisWAM.ps1` | `PurgeAbbeyGazetteEmail` | `PurgeClientEmail` |

---

## 🔴 Still Requires Attention (If Present in Future)

If you add new scripts, check for these patterns before publishing publicly:

- **Tenant IDs / domain names** — anything ending in `.onmicrosoft.com`
- **SharePoint admin URLs** — `*-admin.sharepoint.com`
- **Azure AD Client/App IDs** — UUIDs in app registration scripts
- **Admin UPNs** — `admin@`, `*@*onmicrosoft.com`
- **Client/organisation names** in comments or variable names
- **Compliance search names** that identify a specific client
- **API credentials or tokens** — even placeholder-looking ones

---

*Last reviewed: 2026-05-14 by Ori*
