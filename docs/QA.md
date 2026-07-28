# Quality Gate — Huri

## Rapport — 27 juillet 2026

| Contrôle | Statut | Résultat |
|---|---|---|
| Build Debug | ✅ | Swift 6.2, sans warning |
| Build Release | ✅ | application macOS assemblée |
| Tests | ✅ | 12/12 |
| Images | ✅ | PNG, JPEG et WebP aller-retour |
| PDF | ✅ | fusion, réordre, rotation, split et rendu |
| Détourage | ✅ | image et chaque page d’un PDF |
| Détection | ✅ | signature binaire prioritaire sur l’extension |
| UI native | ✅ | import, conversion réelle et écrans principaux |
| Accessibilité | ✅ | labels, commandes clavier et états exposés |
| Confidentialité | ✅ | aucune API réseau ou télémétrie dans les sources |
| Signature locale | ✅ | signature ad hoc valide |
| Taille | ✅ | 4,6 Mo |

**Verdict : SHIP ✅**

La signature ad hoc convient au test local. Une distribution externe restera à
signer avec un certificat Developer ID et à notariser.

## Definition of Done

- [ ] `swift build` et `swift build -c release` passent sans erreur.
- [ ] `swift test` passe intégralement.
- [ ] La matrice ne propose aucun couple incohérent.
- [ ] Les fixtures PNG/JPEG/WebP/PDF passent en conversion aller-retour.
- [ ] Fusion, rotation, réordre et découpe PDF conservent les pages attendues.
- [ ] Les fichiers corrompus produisent un message utile sans crash.
- [ ] La source n’est jamais écrasée.
- [ ] Le détourage est proposé seulement pour PNG.
- [ ] Import bouton et glisser-déposer sont accessibles au clavier.
- [ ] Les états vide, chargement, erreur et succès sont visibles.
- [ ] L’interface est lisible en thèmes clair et sombre.
- [ ] Le binaire n’intègre aucun SDK réseau ou analytique.
- [ ] `dist/Huri.app` s’ouvre et l’écran principal est testé visuellement.

## Budget

| Mesure | Cible |
|---|---:|
| Temps de démarrage à chaud | < 1 s |
| Mémoire au repos | < 100 Mo |
| Taille de l’app non signée | < 50 Mo |
| Conversion d’une image 12 MP | < 3 s |
| Pics de concurrence | 2 travaux lourds |

## Distribution

La construction locale n’est pas signée. La publication externe exige :

1. signature Developer ID ;
2. Hardened Runtime ;
3. notarisation Apple ;
4. test du DMG sur une session utilisateur propre.
