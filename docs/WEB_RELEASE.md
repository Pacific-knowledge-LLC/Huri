# Déploiement du site Huri

Ce runbook couvre le site statique et les deux images disque macOS distribuées
depuis le même déploiement Vercel.

## Périmètre

- Dépôt : <https://github.com/Pacific-knowledge-LLC/Huri>
- Production : <https://huri-jet.vercel.app>
- Branche de production : `main`
- Hébergeur : Vercel
- Artefact :
  - `https://github.com/Pacific-knowledge-LLC/Huri/releases/latest/download/Huri-macos-universal.dmg`

## Préflight

```bash
git diff --check
make verify
npx html-validate@latest index.html
node --check app.js
```

`make downloads` est réservé au runner de release disposant du certificat
Developer ID et des credentials de notarisation. Il refuse tout build ad hoc.

Vérifier ensuite que le dépôt de travail est propre et que le commit à publier
est présent sur `main` du dépôt Pacific Knowledge.

## Déploiement

Le projet Vercel est lié au dépôt GitHub. Un push sur `main` déclenche le
déploiement. Pour une release manuelle reproductible :

```bash
npx vercel --prod --yes
```

## Validation

Après le déploiement :

1. Ouvrir la page de production sur desktop et mobile.
2. Tester la démo interactive et la recherche de conversions.
3. Vérifier les en-têtes HTTP de sécurité.
4. Télécharger le DMG universel depuis GitHub Releases, vérifier sa somme
   SHA-256, `stapler`, Gatekeeper et les architectures arm64 + x86_64.
5. Exécuter Lighthouse et conserver comme seuils : performance ≥ 95,
   accessibilité = 100 et SEO = 100.

La somme attendue est publiée avec chaque GitHub Release sous
`Huri-macos-universal.dmg.sha256` et ne doit jamais être réutilisée pour une
nouvelle version.

## Rollback

Dans Vercel, ouvrir le dernier déploiement sain et choisir **Promote to
Production**. Le rollback ne modifie pas Git. Corriger ensuite `main` avec un
nouveau commit explicite ; ne pas réécrire l’historique public.
