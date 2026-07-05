# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-07-05

### Added
- Initial public release of the config-driven Google Workspace → Microsoft 365 toolkit.
- 11 PowerShell scripts (`00`–`10`): prerequisites, Google/M365 audit, SharePoint provisioning,
  shared mailboxes, mailbox prep (MRM + aliases), mail endpoint & batches, migration probe,
  cutover DNS values, and Excel dashboard.
- `_Config.ps1` config loader that derives SharePoint/OneDrive URLs, MX and onmicrosoft values.
- Bilingual documentation: English `README.md`, French `README.fr.md`, and the detailed
  French playbook `METHODOLOGIE.md` (what / why / how / what changes per client).
- Example config and CSV templates with placeholder-only data.
- Community files: `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  issue/PR templates, and `.gitignore`.
