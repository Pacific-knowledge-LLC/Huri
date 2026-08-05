# Déploiement du site Huri

Ce runbook couvre le site statique et les deux images disque macOS distribuées
depuis le même déploiement Vercel.

## Périmètre

- Dépôt : <https://github.com/Pacific-knowledge-LLC/Huri>
- Production : <https://huri-jet.vercel.app>
- Branche de production : `main`
- Hébergeur : Vercel
- Artefacts :
  - `downloads/Huri-1.0.0-macos-arm64.dmg`
  - `downloads/Huri-1.0.0-macos-x86_64.dmg`

## Préflight

```bash
git diff --check
make verify
make downloads
npx html-validate@latest index.html
node --check app.js
hdiutil verify downloads/Huri-1.0.0-macos-arm64.dmg
hdiutil verify downloads/Huri-1.0.0-macos-x86_64.dmg
```

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
4. Télécharger les DMG Apple Silicon et Intel, puis comparer leur somme SHA-256.
5. Exécuter Lighthouse et conserver comme seuils : performance ≥ 95,
   accessibilité = 100 et SEO = 100.

Sommes SHA-256 de la version 1.0.0 :

```text
4c581789c6924249cd8e102644165137a8fd39f43c35a1aee2ab2e4df2dcbb05  Huri-1.0.0-macos-arm64.dmg
98d5ff31188b782ee5441e0b6dd7a149f8e4c639471d81063bd6dbf2d2cfca2e  Huri-1.0.0-macos-x86_64.dmg
```

## Rollback

Dans Vercel, ouvrir le dernier déploiement sain et choisir **Promote to
Production**. Le rollback ne modifie pas Git. Corriger ensuite `main` avec un
nouveau commit explicite ; ne pas réécrire l’historique public.
