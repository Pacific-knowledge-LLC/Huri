# Third-party notices

Huri is distributed under the MIT License. The application includes the
following open-source dependency:

## Swift-WebP

- Project: https://github.com/ainame/Swift-WebP
- Copyright: © 2016 Satoshi Namai
- License: MIT
- Purpose: Swift bindings and local WebP encoding/decoding.

The full dependency license is available in the upstream project and is
reproduced in Swift Package Manager's resolved checkout when building Huri.

## Optional local engines

Huri can discover and invoke the following tools when users install them on
their own Mac. They are not bundled, downloaded or redistributed by Huri:

| Engine | Purpose | Upstream license varies by build |
|---|---|---|
| FFmpeg | Audio and video | LGPL/GPL |
| ImageMagick | Long-tail image and vector formats | ImageMagick License |
| LibreOffice | Office and presentation formats | MPL 2.0 / LGPLv3+ |
| Pandoc | Structured documents and EPUB | GPLv2+ |
| calibre | E-book formats | GPLv3 |
| 7-Zip | Archive formats | LGPL / BSD / unRAR restriction |
| FontForge | Font formats | GPLv3 |
| Inkscape | Vector formats | GPLv2+ |

Huri only passes local file paths and arguments to these executables. No engine
is contacted over a network. Before redistributing a build that embeds one of
these engines, review that engine's exact build configuration, codecs and
license obligations.
