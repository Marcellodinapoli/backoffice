# Pubblicare su Netlify

Sito: **https://backofficeadmin.netlify.app**

## Perché il sito non si aggiorna

1. **Push su GitHub ok, ma Netlify non collegato** al repo `Marcellodinapoli/backoffice` (branch `main`).
2. **GitHub Actions fallito** → [Actions](https://github.com/Marcellodinapoli/backoffice/actions): serve configurare i secrets (vedi sotto).
3. **Build fallito** → in Netlify: *Deploys* → ultimo deploy → *Deploy log* (rosso).
4. **Cache browser** → Flutter web usa Service Worker: **Ctrl+Shift+R** o cancella dati sito.
5. **`npm install` automatico** → disattivato in `netlify.toml` con `NETLIFY_SKIP_DEPENDENCIES_INSTALL`.

## Opzione A — Deploy automatico da Netlify (Git)

In [Netlify](https://app.netlify.com) → sito **backofficeadmin** → **Site configuration** → **Build & deploy**:

| Impostazione | Valore |
|--------------|--------|
| Repository | `Marcellodinapoli/backoffice` |
| Branch | `main` |
| Build command | *(vuoto — usa `netlify.toml`)* |
| Publish directory | `build/web` |

Poi **Trigger deploy** → **Deploy site**.

## Opzione B — GitHub Actions (consigliata)

GitHub → [Settings → Secrets → Actions](https://github.com/Marcellodinapoli/backoffice/settings/secrets/actions)

### B1 — Build hook (1 secret, consigliato)

1. Netlify → **backofficeadmin** → **Build & deploy** → **Build hooks** → **Add build hook** (branch `main`)
2. Copia l’URL → secret `NETLIFY_BUILD_HOOK`
3. Push su `main` oppure **Actions** → **Deploy Netlify** → **Run workflow**

### B2 — Token + Site ID (2 secrets)

1. `NETLIFY_AUTH_TOKEN` — Netlify → User settings → Applications
2. `NETLIFY_SITE_ID` — backofficeadmin → Site details → **API ID**

Il workflow builda Flutter su GitHub e carica `build/web` su Netlify.

Deploy riuscito (verde in Actions) → dopo 1–2 min il sito mostra **Carica Setup.exe**.

## Opzione C — Deploy manuale da Windows

```powershell
cd C:\FlutterProjects\backoffice
flutter build web --release
npx netlify-cli deploy --prod --dir=build\web
```

Oppure:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_netlify_local.ps1
```

Richiede: Flutter in PATH, `netlify login`.
