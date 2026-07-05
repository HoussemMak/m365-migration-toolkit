# Contributing

Thanks for your interest in improving the M365 Migration Toolkit! This project grew out of a real Google Workspace → Microsoft 365 migration, and the most valuable contributions are **new gotchas and fixes** discovered in the field.

## Ways to contribute

- **Report a trap you hit** — open an issue with the error code/message, the context, and the fix. These go into [METHODOLOGIE.md](METHODOLOGIE.md).
- **Improve a script** — bug fixes, better error handling, `-WhatIf` support, cross-platform tweaks.
- **Docs** — clarify steps, fix typos, improve the English/French parity.

## Ground rules

1. **Never commit secrets or client data.** No real domains, tenant names, service-account keys, JSON keys, or personal data. Use placeholders (`client.ca`, `employe1@client.ca`, `NomDuClient`). The `.gitignore` blocks the obvious ones — double-check your diff.
2. **Keep it config-driven.** New behavior should read from `config/client-config.json` or `data/*.csv`, not hardcoded values.
3. **Test before you submit.** At minimum, scripts must parse (`pwsh -NoProfile -Command "$null = [scriptblock]::Create((Get-Content -Raw ./scripts/XX.ps1))"`). Describe what you actually ran.
4. **Match the existing style** — PowerShell 7, comment-based help where relevant, French for the playbook, English for the flagship README.

## Pull requests

- Branch from `main`, keep PRs focused.
- Explain **what** changed and **why** (which trap it addresses).
- Update `CHANGELOG.md` under "Unreleased".

## Security

Found something sensitive (a leaked secret in history, a dangerous default)? Please follow [SECURITY.md](SECURITY.md) and report privately — don't open a public issue.
