# Quality Gate — Huri

## Rapport — 29 juillet 2026

| Contrôle | Statut | Résultat |
|---|---|---|
| Build Debug | ✅ | Swift 6.2, sans warning |
| Build Release | ✅ | application macOS assemblée |
| Tests | ✅ | 19/19 |
| Images | ✅ | PNG, JPEG et WebP aller-retour |
| PDF | ✅ | fusion, réordre, rotation, split et rendu |
| Détourage | ✅ | image et chaque page d’un PDF |
| Détection | ✅ | signature binaire prioritaire sur l’extension |
| UI native | ✅ | import, conversion réelle et écrans principaux |
| Accessibilité | ✅ | labels, commandes clavier et états exposés |
| i18n | ✅ | catalogue FR/EN complet, français de repli |
| Onboarding | ✅ | trois écrans, reprise depuis À propos, visite de cinq repères |
| Confidentialité | ✅ | aucune API réseau ou télémétrie dans les sources |
| Signature locale | ✅ | signature ad hoc valide |
| Architectures | ✅ | binaire universel arm64 + x86_64 |
| Taille | ✅ | app 8,4 Mo, DMG 4,1 Mo |

**Verdict local : SHIP ✅**

La build installable et le DMG local sont validés. Les workflows de distribution
externe sont prêts mais exigent les certificats, le profil App Store et les clés
de l’organisation Pacific Knowledge.

Preuves visuelles : [conversion en mode sombre](screenshots/conversion-dark.jpg)
et [cinquième repère de la visite guidée](screenshots/tour-pdf-light.jpg).

## Definition of Done

- [x] `swift build` et les builds Release arm64/x86_64 passent sans erreur.
- [x] `swift test` passe intégralement.
- [x] La matrice ne propose aucun couple incohérent.
- [x] Les fixtures PNG/JPEG/WebP/PDF passent en conversion aller-retour.
- [x] Fusion, rotation, réordre et découpe PDF conservent les pages attendues.
- [x] Les fichiers corrompus produisent un message utile sans crash.
- [x] La source n’est jamais écrasée.
- [x] Le détourage est proposé seulement pour PNG.
- [x] Import bouton et glisser-déposer sont accessibles au clavier.
- [x] Les états vide, chargement, erreur et succès sont visibles.
- [x] L’interface est lisible en thèmes clair et sombre et en fenêtre minimale.
- [x] Le binaire n’intègre aucun SDK réseau ou analytique.
- [x] `dist/Huri.app` et le DMG sont vérifiés ; l’app est installée et testée.

## Budget

| Mesure | Cible |
|---|---:|
| Temps de démarrage à chaud | < 1 s |
| Mémoire au repos | < 100 Mo |
| Taille de l’app non signée | < 50 Mo |
| Conversion d’une image 12 MP | < 3 s |
| Pics de concurrence | 2 travaux lourds |

## Distribution

La construction locale est signée ad hoc. La publication externe exige :

1. signature Developer ID ;
2. Hardened Runtime ;
3. notarisation Apple ;
4. test du DMG sur une session utilisateur propre.

Pour une vérification visuelle reproductible sans modifier l’apparence du Mac,
la build accepte les arguments internes `--qa-light-mode` et
`--qa-dark-mode`. Ils ne créent aucun réglage visible dans l’application.
