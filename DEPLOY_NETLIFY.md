# Pubblicare su Netlify

## Perché il sito non si aggiorna

1. **Push su GitHub ok, ma Netlify non collegato** al repo `Marcellodinapoli/backoffice` (branch `main`).
2. **GitHub Actions fallito** → [Actions](https://github.com/Marcellodinapoli/backoffice/actions): serve configurare i secrets (vedi Opzione B).
3. **Build fallito** → in Netlify: *Deploys* → ultimo deploy → *Deploy log* (rosso).
4. **`npm install` automatico** → disattivato in `netlify.toml` con `NETLIFY_SKIP_DEPENDENCIES_INSTALL`.

## Opzione A — Deploy automatico da Netlify (Git)

In [Netlify](https://app.netlify.com) → sito → **Site configuration** → **Build & deploy**:

| Impostazione | Valore |
|--------------|--------|
| Repository | `Marcellodinapoli/backoffice` |
| Branch | `main` |
| Base directory | *(vuoto)* |
| Build command | *(vuoto — usa `netlify.toml`)* |
| Publish directory | `build/web` |

Poi **Trigger deploy** → **Deploy site**.

## Opzione B — GitHub Actions → backofficeadmin.netlify.app

Sito: **https://backofficeadmin.netlify.app**

GitHub → [Settings → Secrets → Actions](https://github.com/Marcellodinapoli/backoffice/settings/secrets/actions)

### B1 — Build hook (1 secret, consigliato)

1. Netlify → sito **backofficeadmin** → **Build & deploy** → **Build hooks** → **Add build hook** (branch `main`)
2. Copia l’URL → secret `NETLIFY_BUILD_HOOK`
3. Push su `main` oppure **Actions** → **Deploy Netlify** → **Run workflow**

### B2 — Token + Site ID (2 secrets)

1. `NETLIFY_AUTH_TOKEN` — Netlify → User settings → Applications
2. `NETLIFY_SITE_ID` — backofficeadmin → Site details → **API ID**

Il workflow builda Flutter su GitHub e carica `build/web` su Netlify.

## Opzione C — Deploy manuale da Windows

```powershell
cd percorso\backoffice
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_netlify_local.ps1
```

Richiede: Flutter in PATH, `netlify login`.
