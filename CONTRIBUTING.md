# Contributing

Thank you for your interest in improving this repository. Contributions that keep scripts clear, safe, and maintainable are welcome.

## Before you start

- Read the [Code of Conduct](CODE_OF_CONDUCT.md).
- Check existing issues and pull requests to avoid duplication.
- Prefer focused changes. One script or one clear fix per pull request is easier to review.

## What to contribute

- Bug fixes and reliability improvements
- Clearer error handling and confirmation prompts for destructive actions
- Documentation and README accuracy
- New scripts that fit the existing folder structure and style
- Sample CSV templates under `CSVs/` for scripts that accept file input

## Script standards

- Target **Windows PowerShell 5.1** and **PowerShell 7+** where practical.
- Prefer **Microsoft Graph** over legacy modules (MSOnline, AzureAD).
- For destructive operations (purge, password reset, sign-in disable, sync disable):
  - Prompt for required input
  - Show a summary of what will change
  - Require explicit confirmation before applying changes
- Use clear parameter names and `param()` blocks.
- Avoid hard-coded tenant-specific values; prompt or accept parameters instead.
- Keep output readable (Write-Host for status, structured objects for data).

## Folder placement

| Area | Folder |
|------|--------|
| Exchange Online | `M365-Exchange/` |
| Entra ID / Graph users & groups | `M365-Azure/` |
| SharePoint / OneDrive | `M365-SharePoint/` |
| Teams | `M365-Teams/` |
| Email config & audit | `M365-Email/` |
| Intune / devices | `M365-Devices/` |
| Password management | `M365-Passwords/` |
| On-prem Active Directory | `Active-Directory/` |
| Security & audit | `Security-Admin/` |
| Shared utilities | `General-Tools/` |
| Notes and runbooks | `General-Reference/` |
| CSV samples | `CSVs/` |

## Pull request process

1. Fork the repository and create a branch from `main`.
2. Make your changes. Update the README if you add or rename a script.
3. Test on PowerShell 5.1 and/or 7+ where possible.
4. Open a pull request with a short description of the change and why it is needed.
5. Link any related issue.

## Reporting issues

When filing an issue, include:

- Script name and path
- PowerShell version (`$PSVersionTable`)
- Relevant modules and versions
- Exact error message or unexpected behaviour
- Steps to reproduce (sanitise tenant and user data)

## Licence

By contributing, you agree that your contributions will be licensed under the same [MIT Licence](LICENSE) as the rest of the project.
