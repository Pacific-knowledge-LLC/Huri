# Publier Huri

Huri utilise une version sémantique unique dans `VERSION`. Un tag
`vMAJOR.MINOR.PATCH` déclenche les deux distributions après le passage du
quality gate.

## Préparation

1. Mettre `VERSION`, les notes de version FR/EN et les métadonnées Store à jour.
2. Exécuter `make clean verify dmg`.
3. Tester `dist/Huri.app` en français et en anglais, en modes clair et sombre.
4. Fusionner sur `main`, attendre une CI verte, puis créer un tag signé.

```bash
git tag -s v1.0.1 -m "Huri 1.0.1"
git push production v1.0.1
```

Le workflow `Release` peut aussi être relancé manuellement sur un tag existant.
Il refuse un tag qui ne correspond pas à `VERSION`. Le site ne sert aucun DMG
committé : ses CTA pointent vers `Huri-macos-universal.dmg` dans la dernière
GitHub Release validée.

## Secrets GitHub

| Secret | Usage |
|---|---|
| `APPLE_CERTIFICATE_P12` | archive Base64 contenant les certificats de distribution |
| `APPLE_CERTIFICATE_PASSWORD` | mot de passe de l’archive |
| `DEVELOPER_ID_APPLICATION` | nom exact de l’identité Developer ID Application |
| `APP_STORE_APPLICATION_IDENTITY` | identité 3rd Party Mac Developer Application |
| `APP_STORE_INSTALLER_IDENTITY` | identité 3rd Party Mac Developer Installer |
| `APP_STORE_PROVISIONING_PROFILE` | profil Mac App Store encodé en Base64 |
| `ASC_KEY_ID` | identifiant de la clé API App Store Connect |
| `ASC_ISSUER_ID` | issuer de la clé API |
| `ASC_PRIVATE_KEY` | contenu de la clé privée `.p8` |
| `HOMEBREW_TAP_TOKEN` | jeton limité en écriture au tap de l’équipe Pacific Knowledge |

Variable de dépôt GitHub :

| Variable | Usage |
|---|---|
| `HOMEBREW_TAP_REPOSITORY` | dépôt `organisation/homebrew-tap` détenu par Pacific Knowledge |

Les workflows utilisent des permissions GitHub minimales. Les clés sont
écrites uniquement dans le répertoire temporaire du runner et son trousseau
éphémère.

## Canaux

### Mac App Store

Le job assemble l’app sandboxée avec
`Config/Huri.AppStore.entitlements`, crée un paquet signé puis l’envoie à App
Store Connect. Vérifier le traitement du build, l’associer au groupe TestFlight
interne, exécuter le smoke test, puis soumettre la version avec les métadonnées
de `StoreMetadata/`.

### Homebrew

Le job construit un binaire universel arm64 + x86_64, crée les dSYM, signe l’app
avec Developer ID, active Hardened Runtime, crée et signe le DMG, le notarise,
agrafe le ticket et publie les sommes SHA-256 dans une GitHub Release. La
publication GitHub reste indépendante du tap Homebrew : si celui-ci est
configuré, `Casks/huri.rb` est ensuite mis à jour dans le dépôt défini par
`HOMEBREW_TAP_REPOSITORY`.

Smoke test :

```bash
brew tap <organisation-pacific-knowledge>/tap
brew install --cask huri
open -a Huri
```

## Rollback

- App Store : retirer la version de la vente dans App Store Connect et remettre
  la version stable en avant ; ne jamais réutiliser un numéro de build.
- GitHub/Homebrew : désactiver la release fautive, restaurer le cask au dernier
  couple URL/SHA valide et pousser un correctif. Ne pas remplacer silencieusement
  un asset sous le même tag.
- Incident de signature : révoquer le certificat ou la clé API, renouveler les
  secrets GitHub, puis produire un nouveau patch.

Consigner l’incident, le canal touché, l’heure, la version restaurée et les
preuves du smoke test dans le ticket de release.
