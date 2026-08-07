# Quality Gate — Huri

## Rapport — 30 juillet 2026

| Contrôle | Statut | Résultat |
|---|---|---|
| Build Debug | ✅ | Swift 6.2, sans warning |
| Build Release | ✅ | application macOS assemblée |
| Tests | ✅ | 29/29 |
| Catalogue | ✅ | 309 entrées concurrentes normalisées en 305 formats uniques |
| Capacités runtime | ✅ | 172 formats disponibles et 5 moteurs actifs sur le Mac de QA |
| Images | ✅ | PNG, JPEG et WebP aller-retour |
| Médias | ✅ | WAV→MP3 réel avec FFmpeg |
| Documents | ✅ | Markdown→DOCX réel avec Pandoc |
| Archives | ✅ | ZIP→TAR réel, liens symboliques refusés avant extraction |
| PDF | ✅ | fusion, réordre, rotation, split et rendu |
| Détourage | ✅ | image et chaque page d’un PDF |
| Détection | ✅ | signature binaire prioritaire sur l’extension |
| UI native | ✅ | import, choix explicite, conversion PNG réelle et catalogue filtrable |
| Accessibilité | ✅ | labels, commandes clavier et états exposés |
| i18n | ✅ | catalogue FR/EN complet, français de repli |
| Onboarding | ✅ | trois écrans, reprise depuis À propos, visite de cinq repères |
| Confidentialité | ✅ | aucune API réseau ou télémétrie dans les sources |
| Open source | ✅ | licence MIT et notices tierces embarquées dans l’app |
| Signature locale | ✅ | signature ad hoc acceptée uniquement pour le développement |
| Ressources packagées | ✅ | smoke test isolé du dossier `.build` |
| Architectures | ✅ | pipeline de distribution universel arm64 + x86_64 |
| DMG | ✅ | checksum HFS/APFS valide, montage lecture seule et app vérifiée |
| Taille | ✅ | app 5,8 Mo, DMG 3,4 Mo |

**Verdict local : QA ✅ — publication externe interdite sans Developer ID et notarisation**

La build locale est validée pour le développement. Seul le workflow `Release`,
avec certificat Developer ID, Hardened Runtime, notarisation, agrafage et smoke
test isolé, peut produire un téléchargement public.

Preuves visuelles : [catalogue en mode clair](screenshots/formats-light.jpg),
[catalogue en mode sombre](screenshots/formats-dark.jpg),
[conversion en mode sombre](screenshots/conversion-dark.jpg) et
[cinquième repère de la visite guidée](screenshots/tour-pdf-light.jpg).

## Definition of Done

- [x] `swift build` et les builds Release arm64/x86_64 passent sans erreur.
- [x] `swift test` passe intégralement.
- [x] Les 305 identifiants concurrents sont uniques et gardent leurs droits lecture/écriture.
- [x] La matrice ne propose aucun couple incohérent.
- [x] Un format absent du moteur local est catalogué sans être faussement annoncé disponible.
- [x] Les fixtures PNG/JPEG/WebP/PDF passent en conversion aller-retour.
- [x] FFmpeg, Pandoc et les outils d’archives passent une conversion réelle.
- [x] Fusion, rotation, réordre et découpe PDF conservent les pages attendues.
- [x] Les fichiers corrompus produisent un message utile sans crash.
- [x] La source n’est jamais écrasée.
- [x] Les archives à liens symboliques ou chemins non sûrs sont refusées.
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
