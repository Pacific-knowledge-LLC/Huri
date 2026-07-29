# Huri

> Vos fichiers, transformés.

Huri est une application macOS native de conversion et de manipulation de
fichiers. Elle travaille localement, sans compte, sans télémétrie et sans envoi
vers un serveur.

Huri est développé et publié par
[Pacific Knowledge](https://pacificknowledge.dev).

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

Les artefacts locaux sont signés ad hoc. La pipeline de release sait produire
un DMG Developer ID signé et notarisé pour Homebrew ainsi qu’un paquet signé
pour App Store Connect lorsque les secrets Apple sont disponibles. Voir
[le guide de release](docs/RELEASE.md).

## Architecture

Le cœur métier ne dépend d’aucun framework d’interface. Les services natifs
implémentent les protocoles du cœur, puis l’application SwiftUI les orchestre.
Voir [ADR-001](docs/ADR-001.md) et le [rapport QA](docs/QA.md).

## Confidentialité

Huri n’intègre ni backend, ni SDK analytique, ni publicités. L’accès réseau
pendant le build sert uniquement à résoudre les dépendances Swift. L’app
compilée n’effectue aucun appel réseau.

## Langues

L’interface suit automatiquement la langue de macOS. Le français et l’anglais
sont pris en charge, avec le français comme langue de repli. Le catalogue
`Localizable.xcstrings` est la source de vérité ; exécutez
`make localizations` après toute modification.

## Marque et contact

L’identité de Huri s’appuie sur le sens tahitien de « transformer ». Les règles
de marque sont documentées dans [docs/BRAND.md](docs/BRAND.md).

- Site : https://pacificknowledge.dev
- Contact : admin@pacificknowledge.dev
- GitHub : https://github.com/naikibro

## Licence

Logiciel propriétaire © 2026 Pacific Knowledge. Voir [LICENSE](LICENSE).
