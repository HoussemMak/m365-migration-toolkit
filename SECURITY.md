# Security Policy

## Reporting a vulnerability or a leak

If you find a security issue — a leaked secret in the repo/history, a dangerous default, or anything that could expose a tenant — **please do not open a public issue.**

Instead, report it privately via **GitHub Security Advisories** ("Report a vulnerability" on the Security tab) or by contacting the maintainer directly.

Please include:
- what you found and where (file / commit / line),
- the potential impact,
- and, if possible, a suggested fix.

You'll get an acknowledgement as soon as reasonably possible.

## Scope & reminders

This toolkit operates on **production identity, mail and DNS**. Users are responsible for:
- keeping `config/client-config.json` and all service-account keys **out of version control** (see `.gitignore`),
- testing in a lab/pilot before touching production,
- closing org-policy exceptions and deleting service-account keys **after** each migration (see [METHODOLOGIE §8](METHODOLOGIE.md)).

The software is provided **as-is, without warranty** (see [LICENSE](LICENSE)).
