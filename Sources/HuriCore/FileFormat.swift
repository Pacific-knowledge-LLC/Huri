import Foundation

public enum FileFamily: String, CaseIterable, Codable, Sendable {
  case archive
  case audio
  case cad
  case document
  case ebook
  case font
  case image
  case pdf
  case presentation
  case text
  case vector
  case video
  case unsupported

  public var displayName: String {
    switch self {
    case .archive: HuriL10n.text("file.family.archive")
    case .audio: "Audio"
    case .cad: "CAD"
    case .document: HuriL10n.text("file.family.document")
    case .ebook: HuriL10n.text("file.family.ebook")
    case .font: HuriL10n.text("file.family.font")
    case .image: HuriL10n.text("file.family.image")
    case .pdf: "PDF"
    case .presentation: HuriL10n.text("file.family.presentation")
    case .text: HuriL10n.text("file.family.text")
    case .vector: HuriL10n.text("file.family.vector")
    case .video: HuriL10n.text("file.family.video")
    case .unsupported: HuriL10n.text("file.family.unsupported")
    }
  }
}

public enum FormatAccess: String, Codable, Sendable {
  case readOnly = "r"
  case writeOnly = "w"
  case readWrite = "rw"

  public var canRead: Bool { self != .writeOnly }
  public var canWrite: Bool { self != .readOnly }
}

public struct FormatDescriptor: Hashable, Codable, Sendable {
  public let format: FileFormat
  public let family: FileFamily
  public let access: FormatAccess

  public init(format: FileFormat, family: FileFamily, access: FormatAccess) {
    self.format = format
    self.family = family
    self.access = access
  }
}

/// A data-driven file format identifier.
///
/// Huri intentionally does not use a closed enum here: local open-source tools
/// evolve independently of the app and can add a codec without requiring a new
/// binary. The bundled catalog mirrors Convertio's public read/write format
/// matrix while the capability registry only enables pairs that an installed
/// local engine can actually execute.
public struct FileFormat: RawRepresentable, Hashable, Codable, Identifiable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = Self.normalized(rawValue)
  }

  public init(_ rawValue: String) {
    self.init(rawValue: rawValue)
  }

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .jpeg: "JPEG"
    case .tiff: "TIFF"
    case .heic: "HEIC"
    case .docx: "Word (DOCX)"
    case .doc: "Word (DOC)"
    case .rtf: "Rich Text"
    case .txt: HuriL10n.text("file.family.text")
    case .markdown: "Markdown"
    case .unknown: HuriL10n.text("file.format.unknown")
    default: rawValue.uppercased()
    }
  }

  public var preferredExtension: String {
    switch self {
    case .jpeg: "jpg"
    case .tiff: "tiff"
    case .markdown: "md"
    default: rawValue
    }
  }

  public var filenameExtensions: Set<String> {
    switch self {
    case .jpeg: ["jpg", "jpeg", "jpe", "jfi", "jfif", "jif"]
    case .tiff: ["tif", "tiff"]
    case .heic: ["heic", "heif"]
    case .markdown: ["md", "markdown"]
    case .aiff: ["aif", "aiff", "aifc"]
    case .mpeg: ["mpeg", "mpg", "mpe"]
    case .tarGzip: ["tgz", "tar.gz"]
    case .tarBzip2: ["tbz2", "tar.bz2", "tar.bz"]
    case .tarXz: ["txz", "tar.xz"]
    default: [preferredExtension]
    }
  }

  public var descriptor: FormatDescriptor? {
    FormatCatalog.descriptor(for: self)
  }

  public var family: FileFamily {
    switch self {
    case .pdf: .pdf
    case .txt, .markdown, .html, .csv: .text
    case .svg: .vector
    default: descriptor?.family ?? .unsupported
    }
  }

  public var access: FormatAccess {
    descriptor?.access ?? (self == .unknown ? .readOnly : .readWrite)
  }

  public var supportsTransparency: Bool {
    Self.transparentFormats.contains(self)
  }

  public var isLossy: Bool {
    Self.lossyFormats.contains(self)
  }

  public static var allCases: [FileFormat] {
    FormatCatalog.entries.map(\.format)
  }

  public static func from(filenameExtension: String) -> FileFormat {
    let pathLikeExtension = filenameExtension.lowercased().trimmingCharacters(
      in: CharacterSet(charactersIn: ".")
    )
    let aliases: [String: FileFormat] = [
      "aif": .aiff, "aifc": .aiff,
      "heif": .heic,
      "jfi": .jpeg, "jfif": .jpeg, "jif": .jpeg, "jpe": .jpeg, "jpg": .jpeg,
      "md": .markdown,
      "mpe": .mpeg, "mpg": .mpeg,
      "tar.bz": .tarBzip2, "tar.bz2": .tarBzip2, "tbz2": .tarBzip2,
      "tar.gz": .tarGzip, "tgz": .tarGzip,
      "tar.xz": .tarXz, "txz": .tarXz,
      "tif": .tiff,
    ]
    if let alias = aliases[pathLikeExtension] {
      return alias
    }
    let format = FileFormat(pathLikeExtension)
    return FormatCatalog.descriptor(for: format) == nil ? .unknown : format
  }

  public static let png = FileFormat("png")
  public static let jpeg = FileFormat("jpeg")
  public static let webp = FileFormat("webp")
  public static let tiff = FileFormat("tiff")
  public static let heic = FileFormat("heic")
  public static let gif = FileFormat("gif")
  public static let bmp = FileFormat("bmp")
  public static let avif = FileFormat("avif")
  public static let svg = FileFormat("svg")
  public static let pdf = FileFormat("pdf")
  public static let docx = FileFormat("docx")
  public static let doc = FileFormat("doc")
  public static let odt = FileFormat("odt")
  public static let rtf = FileFormat("rtf")
  public static let txt = FileFormat("txt")
  public static let markdown = FileFormat("markdown")
  public static let html = FileFormat("html")
  public static let csv = FileFormat("csv")
  public static let epub = FileFormat("epub")
  public static let mp3 = FileFormat("mp3")
  public static let wav = FileFormat("wav")
  public static let m4a = FileFormat("m4a")
  public static let aiff = FileFormat("aiff")
  public static let flac = FileFormat("flac")
  public static let ogg = FileFormat("ogg")
  public static let opus = FileFormat("opus")
  public static let mp4 = FileFormat("mp4")
  public static let mov = FileFormat("mov")
  public static let m4v = FileFormat("m4v")
  public static let webm = FileFormat("webm")
  public static let mkv = FileFormat("mkv")
  public static let avi = FileFormat("avi")
  public static let mpeg = FileFormat("mpeg")
  public static let zip = FileFormat("zip")
  public static let sevenZip = FileFormat("7z")
  public static let tar = FileFormat("tar")
  public static let tarGzip = FileFormat("tgz")
  public static let tarBzip2 = FileFormat("tbz2")
  public static let tarXz = FileFormat("tar.xz")
  public static let unknown = FileFormat("unknown")

  public static let nativeImageOutputs: [FileFormat] = [
    .png, .jpeg, .webp, .tiff, .heic, .gif, .bmp,
  ]

  private static let transparentFormats: Set<FileFormat> = [
    .png, .webp, .tiff, .heic, .gif, .avif, .svg,
    FileFormat("exr"), FileFormat("jp2"), FileFormat("psd"),
  ]

  private static let lossyFormats: Set<FileFormat> = [
    .jpeg, .webp, .heic, .avif, .mp3, .m4a, .ogg,
    .mp4, .mov, .m4v, .webm, .avi, .mpeg,
    FileFormat("aac"), FileFormat("ac3"), FileFormat("amr"),
    FileFormat("3gp"), FileFormat("wmv"),
  ]

  private static func normalized(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "."))
      .lowercased()
      .replacingOccurrences(of: "mpeg-2", with: "mpeg2")
      .replacingOccurrences(of: "tar.7z", with: "tar.7z")
  }
}

public enum FormatCatalog {
  public static let entries: [FormatDescriptor] = {
    rawCatalog
      .split(whereSeparator: \.isNewline)
      .flatMap { line -> [FormatDescriptor] in
        let parts = line.split(separator: "|", maxSplits: 1)
        guard parts.count == 2, let family = family(named: String(parts[0])) else {
          return []
        }
        return parts[1].split(separator: ",").compactMap { token in
          let formatAndAccess = token.split(separator: ":", maxSplits: 1)
          guard let identifier = formatAndAccess.first else { return nil }
          let format = FileFormat(String(identifier))
          let access =
            formatAndAccess.count == 2
            ? FormatAccess(rawValue: String(formatAndAccess[1])) ?? .readWrite
            : .readWrite
          return FormatDescriptor(format: format, family: family, access: access)
        }
      }
      .reduce(into: [FileFormat: FormatDescriptor]()) { result, descriptor in
        if result[descriptor.format] == nil {
          result[descriptor.format] = descriptor
        }
      }
      .values
      .sorted { lhs, rhs in
        lhs.family == rhs.family
          ? lhs.format.rawValue < rhs.format.rawValue
          : familyOrder(lhs.family) < familyOrder(rhs.family)
      }
  }()

  public static func descriptor(for format: FileFormat) -> FormatDescriptor? {
    descriptorsByFormat[format]
  }

  public static func formats(in family: FileFamily, writableOnly: Bool = false) -> [FileFormat] {
    entries
      .filter { $0.family == family && (!writableOnly || $0.access.canWrite) }
      .map(\.format)
  }

  private static let descriptorsByFormat: [FileFormat: FormatDescriptor] =
    Dictionary(uniqueKeysWithValues: entries.map { ($0.format, $0) })

  private static func family(named value: String) -> FileFamily? {
    switch value {
    case "archives": .archive
    case "audios": .audio
    case "cad": .cad
    case "documents": .document
    case "ebooks": .ebook
    case "fonts": .font
    case "images": .image
    case "presentations": .presentation
    case "vectors": .vector
    case "videos": .video
    default: nil
    }
  }

  private static func familyOrder(_ family: FileFamily) -> Int {
    FileFamily.allCases.firstIndex(of: family) ?? .max
  }

  // Snapshot of the public Convertio format matrix (30 July 2026). Access
  // markers preserve the source distinction between read-only, write-only and
  // bidirectional formats. Availability in Huri remains runtime-verified.
  private static let rawCatalog = """
    archives|7Z:rw,ACE:r,ALZ:r,ARC:r,ARJ:rw,CAB:r,CPIO:rw,DEB:r,JAR:rw,LHA:rw,RAR:rw,RPM:r,TAR:rw,TAR.7Z:rw,TAR.BZ:rw,TAR.LZ:rw,TAR.LZMA:rw,TAR.LZO:rw,TAR.XZ:rw,TAR.Z:rw,TBZ2:rw,TGZ:rw,ZIP:rw
    audios|8SVX:rw,AAC:rw,AC3:rw,AIFF:rw,AMB:rw,AMR:rw,APE:r,AU:rw,AVR:rw,CAF:rw,CDDA:rw,CVS:rw,CVSD:rw,CVU:rw,DSS:r,DTS:rw,DVMS:rw,FAP:rw,FLAC:rw,FSSD:rw,GSM:rw,GSRT:rw,HCOM:rw,HTK:rw,IMA:rw,IRCAM:rw,M4A:rw,M4R:rw,MAUD:rw,MP2:rw,MP3:rw,NIST:rw,OGA:rw,OGG:rw,OPUS:rw,PAF:rw,PRC:rw,PVF:rw,RA:rw,SD2:rw,SHN:r,SLN:rw,SMP:rw,SND:rw,SNDR:rw,SNDT:rw,SOU:rw,SPH:rw,SPX:rw,TAK:r,TTA:rw,TXW:rw,VMS:rw,VOC:rw,VOX:rw,VQF:r,W64:rw,WAV:rw,WMA:rw,WV:rw,WVE:rw,XA:r
    cad|DXF:rw
    documents|ABW:rw,AW:rw,CSV:rw,DBK:rw,DJVU:rw,DOC:rw,DOCM:rw,DOCX:rw,DOT:rw,DOTM:rw,DOTX:rw,HTML:rw,KWD:rw,ODT:rw,OXPS:rw,PDF:rw,RTF:rw,SXW:rw,TXT:rw,WPS:rw,XLS:rw,XLSX:rw,XPS:rw
    ebooks|AZW3:rw,EPUB:rw,FB2:rw,LRF:rw,MOBI:rw,PDB:rw,RB:rw,SNB:rw,TCR:rw
    fonts|AFM:w,BIN:rw,CFF:rw,CID:rw,DFONT:rw,OTF:rw,PFA:rw,PFB:rw,PS:rw,PT3:rw,SFD:rw,T11:rw,T42:rw,TTF:rw,UFO:w,WOFF:rw
    images|3FR:r,ARW:r,AVIF:rw,BMP:rw,CR2:r,CRW:r,CUR:rw,DCM:r,DCR:r,DDS:rw,DNG:r,ERF:r,EXR:rw,FAX:rw,FTS:rw,G3:rw,G4:rw,GIF:rw,GV:r,HDR:rw,HEIC:rw,HEIF:rw,HRZ:rw,ICO:rw,IIQ:r,IPL:rw,JBG:rw,JBIG:rw,JFI:rw,JFIF:rw,JIF:rw,JNX:r,JP2:rw,JPE:rw,JPEG:rw,JPG:rw,JPS:rw,K25:r,KDC:r,MAC:r,MAP:rw,MEF:r,MNG:rw,MRW:r,MTV:rw,NEF:r,NRW:r,ORF:r,OTB:rw,PAL:rw,PALM:rw,PAM:rw,PBM:rw,PCD:rw,PCT:rw,PCX:rw,PDB:rw,PEF:r,PES:r,PFM:rw,PGM:rw,PGX:rw,PICON:rw,PICT:rw,PIX:r,PLASMA:r,PNG:rw,PNM:rw,PPM:rw,PSD:rw,PWP:r,RAF:r,RAS:rw,RGB:rw,RGBA:rw,RGBO:rw,RGF:rw,RLA:r,RLE:r,RW2:r,SCT:r,SFW:r,SGI:rw,SIX:rw,SIXEL:rw,SR2:r,SRF:r,SUN:rw,SVG:rw,TGA:rw,TIFF:rw,TIM:r,TM2:r,UYVY:rw,VIFF:rw,VIPS:rw,WBMP:rw,WEBP:rw,WMZ:r,WPG:r,X3F:r,XBM:rw,XC:r,XCF:r,XPM:rw,XV:rw,XWD:rw,YUV:rw
    presentations|ODP:rw,POT:rw,POTM:rw,POTX:rw,PPS:rw,PPSM:rw,PPSX:rw,PPT:rw,PPTM:rw,PPTX:rw
    vectors|AFF:r,AI:rw,CCX:r,CDR:r,CDT:r,CGM:rw,CMX:r,DST:r,EMF:rw,EPS:rw,EXP:r,FIG:rw,PCS:r,PES:r,PLT:rw,PS:rw,SK:rw,SK1:rw,SVG:rw,WMF:rw
    videos|3G2:rw,3GP:rw,AAF:r,ASF:rw,AV1:rw,AVCHD:rw,AVI:rw,CAVS:r,DIVX:rw,DV:r,F4V:rw,FLV:rw,HEVC:rw,M2TS:rw,M2V:rw,M4V:rw,MJPEG:rw,MKV:rw,MOD:r,MOV:rw,MP4:rw,MPEG:rw,MPEG2:rw,MPG:rw,MTS:rw,MXF:rw,OGV:rw,RM:rw,RMVB:rw,SWF:rw,TOD:r,TS:rw,VOB:rw,WEBM:rw,WMV:rw,WTV:rw,XVID:rw
    """
}
