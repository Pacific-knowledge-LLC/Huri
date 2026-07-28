# Huri

> Vos fichiers, simplement.

Huri est une application macOS native de conversion et de manipulation de
fichiers. Elle travaille localement, sans compte, sans télémétrie et sans envoi
vers un serveur.

![Conversion locale dans Huri](docs/screenshots/conversion-dark.jpg)

## Fonctionnalités

- Détection du contenu et proposition des seules conversions cohérentes.
- Images : PNG, JPEG, WebP, TIFF, HEIC, GIF et BMP.
- Images vers PDF et PDF multipage vers images.
- Détourage automatique avec Vision lors d’un export PNG.
- PDF : aperçu, fusion, réordre, rotation, suppression de pages et découpe.
- Texte/RTF vers PDF ou image.
- Audio : MP3, M4A, WAV et AIFF vers les formats compatibles.
- Vidéo : MOV, MP4 et M4V, avec extraction audio M4A.
- Import par glisser-déposer ou sélecteur macOS, traitement par lot et
  progression.

### À propos de Word

macOS ne fournit pas d’API publique capable de rendre fidèlement DOC/DOCX en
PDF. Huri détecte donc un fournisseur LibreOffice installé localement et
active la conversion Word uniquement lorsqu’il est disponible. Aucun paquet
de plusieurs centaines de mégaoctets n’est incorporé dans Huri.

## Principes

- **Privé** : chaque octet reste sur le Mac.
- **Natif** : SwiftUI, AppKit, PDFKit, Image I/O, Vision et AVFoundation.
- **Léger** : une seule dépendance de production, `libwebp`, pour garantir
  l’encodage WebP.
- **Prudent** : le fichier source n’est jamais modifié et les exports utilisent
  des noms uniques.

## Prérequis

- macOS 14 ou version ultérieure.
- Xcode 16 ou version ultérieure (Xcode 26 et Swift 6.2 recommandés).
- LibreOffice facultatif pour DOC/DOCX.

## Développement

```bash
make build
make test
make run
```

Le projet est un package Swift afin de rester lisible et reproductible. Xcode
peut ouvrir directement `Package.swift`.

## Créer l’application

```bash
make package
open dist/Huri.app
```

Pour créer une image disque locale :

```bash
make dmg
```

Les artefacts locaux ne sont pas signés. Une distribution publique nécessite
un certificat Developer ID, le Hardened Runtime et la notarisation Apple.

## Architecture

Le cœur métier ne dépend d’aucun framework d’interface. Les services natifs
implémentent les protocoles du cœur, puis l’application SwiftUI les orchestre.
Voir [ADR-001](docs/ADR-001.md) et le [rapport QA](docs/QA.md).

## Confidentialité

Huri n’intègre ni backend, ni SDK analytique, ni publicités. L’accès réseau
pendant le build sert uniquement à résoudre les dépendances Swift. L’app
compilée n’effectue aucun appel réseau.

## Licence

Logiciel propriétaire. Voir [LICENSE](LICENSE).
