# M365 Migration Toolkit — Google Workspace → Microsoft 365

> 🇬🇧 **English version:** [README.md](README.md)

Boîte à outils **réutilisable** pour migrer un client de Google Workspace vers Microsoft 365 (mail + Drive), avec les **outils gratuits natifs de Microsoft**, tirée d'un mandat réel (OSBL). **Générique** : un seul fichier de config + des CSV à remplir par client ; les scripts en déduisent tout le reste.

👉 **Playbook détaillé (quoi / pourquoi / comment / ce qui change par client) : [METHODOLOGIE.md](METHODOLOGIE.md).**

## 📁 Structure
```
m365-migration-toolkit/
├── README.md / README.fr.md         Ce fichier (EN / FR)
├── METHODOLOGIE.md                  Playbook détaillé (étapes, explications, pièges)
├── config/
│   ├── client-config.example.json   Modèle de configuration (à copier)
│   └── client-config.json           (À CRÉER par client — ignoré par git)
├── data/                            CSV à remplir par client (après l'audit)
│   ├── shared-drives.csv            Disques partagés -> bibliothèques (Source, Slug, Title)
│   ├── mailboxes.csv                Boîtes (EmailAddress, DisplayName, Type, OneDrive)
│   ├── aliases.csv                  Alias -> adresse secondaire (MailboxSmtp, AliasSmtp)
│   ├── results-mail.csv             Résultats mail (pour le dashboard)
│   └── results-drive.csv            Résultats Drive (pour le dashboard)
├── scripts/                         00 à 10 (voir tableau plus bas)
└── reports/                         (Sorties : audits, rapports MM, dashboard)
```

## 🚀 Démarrage rapide (par client)
1. **Config** : copier `config/client-config.example.json` → `config/client-config.json`, remplir.
2. **Prérequis** : `pwsh scripts/00-Check-Prerequisites.ps1`
3. **Accès** (une fois par client) — voir METHODOLOGIE §3 :
   - `Register-PnPEntraIDAppForInteractiveLogin` → `pnpClientId`
   - `gam create project` + `gam oauth create` → compte de service + débloquer règles d'org → `serviceAccountEmail/KeyPath`
   - Délégation domaine (DWD) avec les scopes fournis
4. **Audit** : `01-Audit-Google.ps1`, `02-Audit-M365.ps1` → remplir les `data/*.csv`.
5. **Cible** : `03-Provision-SharePoint.ps1`, `04-Create-SharedMailboxes.ps1`, `05-Prep-Mailboxes.ps1`
6. **Mail** : `06-Create-MailEndpoint.ps1` → `07-Start-MailBatch.ps1` (pilote puis vagues)
7. **Drive** : Migration Manager (GUI) avec les CSV ; suivi via `08-Probe-Migration.ps1`
8. **Cutover** : `09-Get-CutoverDnsValues.ps1` → changements DNS (METHODOLOGIE §7)
9. **Dashboard** : remplir `data/results-*.csv` → `10-Build-Dashboard.ps1`

## ⚠️ Ce qui doit être refait pour chaque client
App Entra (PnP ClientId) · projet/compte de service Google (+ déblocage règles d'org) · délégation domaine · CNAME DKIM (par tenant). **Détails complets dans METHODOLOGIE.md §10.**

## ⚠️ Avertissement
Fourni **tel quel, sans garantie** (voir [LICENSE](LICENSE)). Ces scripts touchent au **routage mail, au DNS et aux permissions** de tenants en production. **Toujours tester en labo / pilote d'abord**, lire chaque script avant de l'exécuter, garder un plan de rollback (TTL DNS courts). Ne jamais committer `config/client-config.json` ni les clés JSON (secrets).

## Notes
- Lancer les scripts **PnP/Exchange/Graph** depuis un poste avec navigateur (auth interactive).
- Lancer **GAM** (audit Google) dans un terminal local autorisé.
- **Migration Manager (Drive)** : interface graphique uniquement (pas d'API) — le toolkit prépare/suit, le lancement est manuel.

## Contribuer
Issues et PR bienvenues — voir [CONTRIBUTING.md](CONTRIBUTING.md). Signaler tout élément sensible en privé (voir [SECURITY.md](SECURITY.md)).

## Licence
[MIT](LICENSE).
