# Matrice concurrentielle — Huri, iLovePDF et Convertio

Audit réalisé le 30 juillet 2026 à partir des sources officielles :

- [iLovePDF — tous les outils](https://www.ilovepdf.com/)
- [iLovePDF — guide utilisateur](https://www.ilovepdf.com/help/documentation)
- [iLovePDF — limites et plans](https://www.ilovepdf.com/pricing)
- [Convertio — catalogue des formats](https://convertio.co/formats/)
- [Convertio — limite gratuite](https://support.convertio.co/hc/en-us/articles/360004386774-Free-tier-limit-for-file-conversions)

## Positionnement

| Critère | iLovePDF Basic | Convertio Free | Huri |
|---|---|---|---|
| Traitement | Cloud | Cloud | 100 % local |
| Compte | Selon fonctions | Selon usage | Aucun |
| Limite fichier | 15–400 Mo selon outil | 100 Mo | Espace/RAM du Mac |
| Quota | Limites par tâche | 10 fichiers/24 h | Aucun |
| Concurrence | Selon plan | 2 tâches | 2 travaux lourds ciblés |
| Formats publics | PDF/Office/images ciblés | 309 entrées / 305 noms | 305 noms catalogués |
| Open source | Non | Non | MIT |
| API/backend requis | Oui | Oui | Non |

## Familles Convertio

Le snapshot versionné dans `FormatCatalog` conserve aussi les marqueurs
lecture seule (`r`), écriture seule (`w`) et bidirectionnels (`rw`).

| Famille | Entrées publiques | Moteur Huri |
|---|---:|---|
| Archives | 23 | outils macOS, 7-Zip facultatif |
| Audio | 62 | AVFoundation, FFmpeg facultatif |
| CAD | 1 | moteur facultatif |
| Documents | 23 | natif, LibreOffice, Pandoc |
| E-books | 9 | Pandoc, calibre facultatif |
| Polices | 16 | FontForge facultatif |
| Images | 108 | Image I/O, WebP, ImageMagick facultatif |
| Présentations | 10 | LibreOffice |
| Vecteurs | 20 | ImageMagick/Inkscape facultatifs |
| Vidéos | 37 | AVFoundation, FFmpeg facultatif |

Les quatre identifiants ambigus présents dans plusieurs familles chez Convertio
(`PDB`, `PES`, `PS`, `SVG`) sont normalisés vers une famille canonique. Huri ne
prétend pas que toute combinaison parmi 305 formats est valide : la paire
entrée/sortie reste filtrée par moteur, famille et droit d’écriture.

## Conversions iLovePDF

| Conversion | Huri | Règle/exception |
|---|---|---|
| Images→PDF | Oui | un lot devient un PDF multipage ordonné |
| PDF→images | Oui | une sortie par page, DPI 72–600 |
| DOC/DOCX→PDF | Oui si LibreOffice | macros non exécutées ; polices manquantes possibles |
| PPT/PPTX→PDF | Oui si LibreOffice | animations et transitions deviennent statiques |
| XLS/XLSX→PDF | Oui si LibreOffice | zones d’impression et polices pilotent la pagination |
| HTML local→PDF | Oui via moteurs locaux | une URL distante n’est pas compatible avec le mode offline |
| PDF→DOCX/PPTX/XLSX | Non annoncé | fidélité éditable non démontrée localement |
| PDF→PDF/A | Non annoncé | exige validation de conformité et polices incorporées |
| PDF→Markdown | Extraction native à venir | ordre de lecture/tableaux à valider |

Les outils iLovePDF qui ne sont pas des conversions (compression, OCR,
réparation, sécurité, formulaires, signature distribuée, IA) restent suivis
séparément. Les workflows nécessitant e-mails, cloud ou coordination distante
sont explicitement hors périmètre d’une application sans serveur.

## Règles transverses implémentées

- détection du contenu avant l’extension pour les signatures fiables ;
- distinction des conteneurs Office OLE par extension lorsque la signature est
  intrinsèquement ambiguë ;
- formats source uniquement exclus des sorties ;
- alpha aplati pour les sorties opaques du moteur étendu ;
- qualité et métadonnées seulement affichées quand elles ont un effet ;
- destination unique, écriture temporaire et source jamais écrasée ;
- protection contre path traversal, liens symboliques et bombes d’archives ;
- aucun shell, aucune URL distante, aucune clé API.

## Limites honnêtes

La présence d’une extension ne garantit jamais un codec, une police, un profil
colorimétrique ou une mise en page. Les moteurs open source remontent donc leur
erreur exacte. Les formats protégés par DRM, les mots de passe inconnus et les
signatures électroniques distribuées ne sont pas contournés.
