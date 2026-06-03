# Pubblicare su Netlify

## Perché il sito non si aggiorna

1. **Push su GitHub ok, ma Netlify non collegato** al repo `Marcellodinapoli/backoffice` (branch `main`).
2. **Build fallito** → in Netlify: *Deploys* → ultimo deploy → *Deploy log* (rosso).
3. **`npm install` automatico** → disattivato in `netlify.toml` con `NETLIFY_SKIP_DEPENDENCIES_INSTALL`.

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

## Opzione B — GitHub Actions (consigliata se A non parte)

1. Netlify → **User settings** → **Applications** → crea **Personal access token**.
2. Netlify → sito → **Site configuration** → **Site details** → copia **Site ID** (API ID).
3. GitHub → repo → **Settings** → **Secrets and variables** → **Actions** → aggiungi:
   - `NETLIFY_AUTH_TOKEN`
   - `NETLIFY_SITE_ID`
4. Push su `main`: il workflow `.github/workflows/netlify-deploy.yml` builda e pubblica.

Controlla esito in GitHub → tab **Actions**.

## Opzione C — Deploy manuale da Windows

```powershell
cd percorso\backoffice
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_netlify_local.ps1
```

Richiede: Flutter in PATH, `netlify login`.
