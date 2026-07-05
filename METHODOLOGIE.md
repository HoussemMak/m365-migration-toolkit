# Méthodologie — Migration Google Workspace → Microsoft 365

> Playbook réutilisable, tiré d'un mandat réel de migration (OSBL). Chaque phase explique **quoi**, **pourquoi**, **comment**, et **ce qui change par client**.
> Le SEUL fichier à personnaliser par client : `config/client-config.json` (+ les CSV de `data/`).

---

## 0. Principes & architecture cible

- **Mail** (Gmail + Agenda + Contacts) → **Exchange Online** (outil natif gratuit « Migrer Google Workspace »).
- **Fichiers** (My Drives + Disques partagés) → **SharePoint / OneDrive** (outil natif gratuit **Migration Manager**).
- **Pré-chargement + incrémentiel** : on copie tout pendant que Google reste actif, puis on bascule (cutover DNS) sur une fenêtre courte.
- **Permissions Google non reprises** (sauf demande) → architecture cible simplifiée.

### Outils requis
- PowerShell 7, modules **PnP.PowerShell**, **ExchangeOnlineManagement**, **Microsoft.Graph.Authentication**.
- **GAM7** (audit Google) — https://github.com/GAM-team/GAM
- **Excel** (dashboard), un **navigateur** (auth interactive).
- Accès **super admin Google** + **admin global / Exchange / SharePoint** M365 + accès **DNS** (GoDaddy, Cloudflare…).

---

## 1. Phase 0 — Configurer le toolkit (par client)

1. Copier `config/client-config.example.json` → `config/client-config.json` et remplir : domaine Google, super admin, tenant M365, adminUpn, site d'archivage, etc.
2. Lancer `scripts\00-Check-Prerequisites.ps1` → vérifie modules, GAM, config, clé.
3. Les listes spécifiques (disques, boîtes, alias) se remplissent dans `data/*.csv` **après l'audit**.

---

## 2. Phase 1 — Audit (dimensionner)

- **Google** : `scripts\01-Audit-Google.ps1` → utilisateurs, groupes, alias, **stockage Drive/Gmail**, disques partagés. (Dans le terminal du poste, GAM doit être autorisé.)
- **M365** : `scripts\02-Audit-M365.ps1` → boîtes existantes, domaines acceptés, **licences (SKU)**, sites SharePoint.
- **DNS** : exporter la zone actuelle (MX, SPF, DKIM, web) depuis le registrar — sert de référence + rollback.

**Livrable** : volumétrie (Go mail / My Drives / disques partagés), mapping des comptes (qui migre, qui est exclu/doublon), licences suffisantes ?

> ⚠️ **Piège — comptes archivés** : un compte Google « Archived User » n'a NI Calendar NI Drive actifs → la migration échoue (`notACalendarUser` 403). Repérer ces comptes à l'audit. Solution : **réactiver** (licence active) le temps de migrer, puis ré-archiver.

---

## 3. Phase 2 — Mettre en place les accès (le plus délicat)

C'est ici que se concentrent **les changements par client**. Chaque tenant/org nécessite ses propres applications et identifiants.

### 2.1 App Entra pour PnP (par tenant M365)
```powershell
Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP Migration <CLIENT>" -Tenant <tenant>.onmicrosoft.com
```
→ Récupérer le **ClientId** → le mettre dans `microsoft365.pnpClientId` du config.
> NB : depuis PnP 2.99+, plus d'app multi-tenant intégrée → **enregistrement obligatoire par client**.

### 2.2 Compte de service Google (par org Google)
Dans le terminal, connecté en super admin :
```powershell
gam create project        # crée le projet GCP + APIs + compte de service
gam oauth create          # autorise l'admin (oauth2.txt) ; au menu scopes, taper "c"
```
→ Marquer le **Client ID GAM** comme « de confiance » dans Admin Google → Contrôle des API.

> ⚠️ **Piège — règles d'organisation « sécurisé par défaut »** : certaines orgs bloquent la création/upload de clés de compte de service (`iam.disableServiceAccountKeyCreation` / `...KeyUpload`). Les outils Microsoft EXIGENT une clé JSON. Solution (avec un compte ayant `orgpolicy.policyAdmin`) :
> ```powershell
> ORG_ID=$(gcloud projects get-ancestors <projet> --format="value(id,type)" | grep organization | awk '{print $1}')
> gcloud organizations add-iam-policy-binding "$ORG_ID" --member="user:<superadmin>" --role="roles/orgpolicy.policyAdmin"
> gcloud resource-manager org-policies disable-enforce iam.disableServiceAccountKeyCreation --project=<projet>
> gcloud resource-manager org-policies disable-enforce iam.disableServiceAccountKeyUpload  --project=<projet>
> gcloud iam service-accounts keys create key.json --iam-account=<sa-email>
> ```
> → Renseigner `serviceAccountEmail` + `serviceAccountKeyPath` dans le config. **Refermer ces règles + supprimer la clé après migration.**
> Le rôle `orgpolicy.policyAdmin` **n'est PAS attribuable au niveau projet** → l'attribuer au niveau **organisation**.

### 2.3 Délégation au niveau du domaine (DWD) (par org Google)
Admin Google → Sécurité → Contrôle des API → **Délégation à l'échelle du domaine** → Ajouter le **Client ID du compte de service** (son `uniqueId` numérique) avec les scopes :
```
https://mail.google.com/,https://www.googleapis.com/auth/calendar,https://www.google.com/m8/feeds/,https://www.googleapis.com/auth/gmail.settings.sharing,https://www.googleapis.com/auth/contacts,https://www.googleapis.com/auth/drive.readonly,https://www.googleapis.com/auth/admin.directory.user.readonly,https://www.googleapis.com/auth/admin.directory.group.readonly
```
> ⚠️ **Piège — scopes mail** : la migration Gmail exige `https://www.google.com/m8/feeds/` ET `gmail.settings.sharing` (souvent oubliés) → sinon `unauthorized_client / not authorized for any of the scopes`. La délégation peut prendre **15 min à 24 h** à se propager.

---

## 4. Phase 3 — Provisionner la cible M365

- **SharePoint** : `scripts\03-Provision-SharePoint.ps1` → crée le site d'archivage + 1 bibliothèque par disque partagé (depuis `data/shared-drives.csv`).
  > ⚠️ **Piège — URLs SharePoint** : créer la bibliothèque avec un **slug propre** (sans accent/espace/`.`/`+`/`-`) puis renommer avec le titre = nom Google. Sinon URL « sale » (doubles espaces) qui casse le CSV de destinations Migration Manager. (Géré par le script : colonnes `Slug` + `Title`.)
- **Boîtes partagées** : `scripts\04-Create-SharedMailboxes.ps1` (depuis `data/mailboxes.csv`, lignes `Type=Shared`). Gratuites (< 50 Go).
- **Préparation des boîtes** : `scripts\05-Prep-Mailboxes.ps1` → **MRM/rétention en pause** (évite faux « éléments manquants ») + **alias** en adresses secondaires (depuis `data/aliases.csv`).

---

## 5. Phase 4 — Migration du mail

1. **Endpoint** : `scripts\06-Create-MailEndpoint.ps1` (teste + crée le tunnel Gmail→Exchange).
2. **Lots** : `scripts\07-Start-MailBatch.ps1 -CsvPath <wave.csv> -BatchName "Vague1" -AutoStart`
   - Le CSV contient une colonne `EmailAddress` (boîtes M365 cibles).
   - Faire un **pilote** (1 petite boîte) → valider → puis les vagues.
3. **Option A (recommandée)** : **NE PAS compléter** les lots avant le cutover → ils resynchronisent les nouveaux mails ~toutes les 24 h.
> ⚠️ Désactiver MRM/archivage AVANT (fait en 5). Le « 5926 → 3759 » est normal (Gmail compte 1 msg/libellé, Exchange dédoublonne).
> ⚠️ Licence Exchange à assigner seulement APRÈS le démarrage du lot (30 j de délai).

---

## 6. Phase 5 — Migration du Drive (Migration Manager)

**Important : Migration Manager (Google Drive) n'a AUCUNE API/PowerShell** → tout se fait dans l'**interface** du centre d'admin SharePoint. Le toolkit prépare les CSV et suit la progression, mais le lancement est manuel.

1. Centre admin SharePoint → **Migration** → **Google Workspace** → **Connexion** (OAuth super admin, ou clé JSON).
2. **Ajouter des sources** (CSV) : format `/[nom disque]` (disques partagés) ou `email` (My Drives).
3. **Destinations** : télécharger le **modèle MigrationDestinations.csv** depuis MM, remplir la colonne « Chemin de destination » (utiliser les URLs propres des bibliothèques / OneDrive). Pour les disques contenant des **Google Forms**, remplir « Destination des formulaires » (un utilisateur licencié avec OneDrive).
4. **Migrate** (le plus gros disque en premier). Exécution **dans le cloud** (poste éteint OK).
5. **Incrémentiel** : re-déclencher « Migrate » = **delta** (nouveau/modifié seulement). **MANUEL** (contrairement au mail) → planifier des passes + une finale au cutover.

> ⚠️ **Pièges Drive** :
> - **Nom de disque inexact** → `MNOTUSERORTEAMDRIVE` : vérifier le nom EXACT (Gérer les disques partagés) ou re-sélectionner dans la liste.
> - **Jeton expiré pendant le scan** → `MAUTHACCESSTOKENINVALID` : rafraîchir la connexion Google + re-scanner.
> - **Raccourcis Google** → `MEXPORTFILEUNSUPPORTEDMIMETYPE` : bénin (pointeurs, pas des fichiers).
> - **Chemin > 400 car.** → `MITEMPATHLENGTH` : raccourcir le dossier source, ou reprendre les fichiers manuellement.
> - **NE PAS renommer/déplacer** de dossiers côté Google pendant la fenêtre (sinon doublons à l'incrémentiel). Édition/ajout = OK.

---

## 7. Phase 6 — Cutover DNS

Obtenir les valeurs exactes : `scripts\09-Get-CutoverDnsValues.ps1` (calcule MX/SPF, récupère les **CNAME DKIM réels** du tenant).

- **J-2** : baisser les TTL (MX/SPF) à 300 s ; publier les **CNAME DKIM** + `autodiscover` ; communiquer.
- **J0** : basculer **MX** → `<domaine-tirets>.mail.protection.outlook.com` (prio 0) ; **SPF** + `include:spf.protection.outlook.com` ; **activer DKIM** (`Set-DkimSigningConfig -Enabled $true`) ; tester (SPF/DKIM = pass) ; redirection Google en filet.
- **Rollback** : repointer le MX vers Google (TTL court → ~15 min).
> ⚠️ Format DKIM récent : `selector1-<domaine-tirets>._domainkey.<tenant>.r-v1.dkim.mail.microsoft` (≠ ancien `onmicrosoft.com`) → toujours récupérer via `Get-DkimSigningConfig`.
> ⚠️ NE PAS toucher : enregistrements du **site web** (A/CNAME/Cloudflare), sous-domaines tiers (AWS…), **DKIM marketing** (HubSpot…).

---

## 8. Phase 7 — Post-migration & décommission

- Compléter les lots mail ; remonter les TTL ; surveiller le flux 24-72 h ; vérifier DMARC.
- Reprendre les fichiers en échec (chemins longs).
- **Durcir DMARC** (`none` → `quarantine` → `reject`) ; nettoyer le SPF (retirer Google).
- **Ré-archiver** les comptes réactivés ; **refermer les règles d'org Google** + supprimer les clés du compte de service.
- **Décommissionner Google** après 2-4 semaines stables.

---

## 9. Suivi & dashboard

- `scripts\08-Probe-Migration.ps1` : sonde **live** (mail via Exchange ; Drive via la destination SharePoint/OneDrive — pas besoin d'export pour la progression ; codes d'erreur via les rapports MM exportés dans `reports/`).
  > Pour suivre les OneDrive en live, accorder à l'admin l'accès **admin de collection** sur chaque OneDrive (`Set-PnPTenantSite -Owners`).
- `scripts\10-Build-Dashboard.ps1` : classeur Excel à partir de `data/results-mail.csv` + `data/results-drive.csv`.

---

## 10. Récapitulatif — CE QUI CHANGE PAR CLIENT

| Élément | Où | Comment l'obtenir |
|---|---|---|
| Domaine Google, super admin | `config` | Connu |
| Tenant M365, adminUpn | `config` | Connu |
| **pnpClientId** | `config` | `Register-PnPEntraIDAppForInteractiveLogin` (par tenant) |
| **serviceAccountEmail / KeyPath** | `config` | `gam create project` (+ débloquer règles d'org) |
| Site d'archivage, owner | `config` | Choix projet |
| targetDeliveryDomain | `config` | `<tenant>.onmicrosoft.com` |
| **DWD scopes** | Admin Google | Liste fixe (§3.3) — à ré-ajouter par org |
| **CNAME DKIM** | DNS | `Get-DkimSigningConfig` (par tenant) |
| Liste disques partagés | `data/shared-drives.csv` | Audit |
| Boîtes & alias | `data/mailboxes.csv`, `aliases.csv` | Audit |

Tout le reste (URLs SharePoint/OneDrive, MX, structure des scripts) est **dérivé automatiquement** du config par `_Config.ps1`.
