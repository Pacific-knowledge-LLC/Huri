const families = [
  { id: "all", label: "Tous", formats: [] },
  { id: "images", label: "Images", formats: ["3FR", "ARW", "AVIF", "BMP", "CR2", "CRW", "CUR", "DCM", "DCR", "DDS", "DNG", "ERF", "EXR", "FAX", "FTS", "G3", "G4", "GIF", "GV", "HDR", "HEIC", "HEIF", "HRZ", "ICO", "IIQ", "IPL", "JBG", "JBIG", "JFI", "JFIF", "JIF", "JNX", "JP2", "JPE", "JPEG", "JPG", "JPS", "K25", "KDC", "MAC", "MAP", "MEF", "MNG", "MRW", "MTV", "NEF", "NRW", "ORF", "OTB", "PAL", "PALM", "PAM", "PBM", "PCD", "PCT", "PCX", "PDB", "PEF", "PES", "PFM", "PGM", "PGX", "PICON", "PICT", "PIX", "PLASMA", "PNG", "PNM", "PPM", "PSD", "PWP", "RAF", "RAS", "RGB", "RGBA", "RGBO", "RGF", "RLA", "RLE", "RW2", "SCT", "SFW", "SGI", "SIX", "SIXEL", "SR2", "SRF", "SUN", "SVG", "TGA", "TIFF", "TIM", "TM2", "UYVY", "VIFF", "VIPS", "WBMP", "WEBP", "WMZ", "WPG", "X3F", "XBM", "XC", "XCF", "XPM", "XV", "XWD", "YUV"] },
  { id: "audios", label: "Audio", formats: ["8SVX", "AAC", "AC3", "AIFF", "AMB", "AMR", "APE", "AU", "AVR", "CAF", "CDDA", "CVS", "CVSD", "CVU", "DSS", "DTS", "DVMS", "FAP", "FLAC", "FSSD", "GSM", "GSRT", "HCOM", "HTK", "IMA", "IRCAM", "M4A", "M4R", "MAUD", "MP2", "MP3", "NIST", "OGA", "OGG", "OPUS", "PAF", "PRC", "PVF", "RA", "SD2", "SHN", "SLN", "SMP", "SND", "SNDR", "SNDT", "SOU", "SPH", "SPX", "TAK", "TTA", "TXW", "VMS", "VOC", "VOX", "VQF", "W64", "WAV", "WMA", "WV", "WVE", "XA"] },
  { id: "videos", label: "Vidéo", formats: ["3G2", "3GP", "AAF", "ASF", "AV1", "AVCHD", "AVI", "CAVS", "DIVX", "DV", "F4V", "FLV", "HEVC", "M2TS", "M2V", "M4V", "MJPEG", "MKV", "MOD", "MOV", "MP4", "MPEG", "MPEG2", "MPG", "MTS", "MXF", "OGV", "RM", "RMVB", "SWF", "TOD", "TS", "VOB", "WEBM", "WMV", "WTV", "XVID"] },
  { id: "documents", label: "Documents", formats: ["ABW", "AW", "CSV", "DBK", "DJVU", "DOC", "DOCM", "DOCX", "DOT", "DOTM", "DOTX", "HTML", "KWD", "ODT", "OXPS", "PDF", "RTF", "SXW", "TXT", "WPS", "XLS", "XLSX", "XPS"] },
  { id: "archives", label: "Archives", formats: ["7Z", "ACE", "ALZ", "ARC", "ARJ", "CAB", "CPIO", "DEB", "JAR", "LHA", "RAR", "RPM", "TAR", "TAR.7Z", "TAR.BZ", "TAR.LZ", "TAR.LZMA", "TAR.LZO", "TAR.XZ", "TAR.Z", "TBZ2", "TGZ", "ZIP"] },
  { id: "vectors", label: "Vecteurs", formats: ["AFF", "AI", "CCX", "CDR", "CDT", "CGM", "CMX", "DST", "EMF", "EPS", "EXP", "FIG", "PCS", "PES", "PLT", "PS", "SK", "SK1", "SVG", "WMF"] },
  { id: "fonts", label: "Polices", formats: ["AFM", "BIN", "CFF", "CID", "DFONT", "OTF", "PFA", "PFB", "PS", "PT3", "SFD", "T11", "T42", "TTF", "UFO", "WOFF"] },
  { id: "presentations", label: "Présentations", formats: ["ODP", "POT", "POTM", "POTX", "PPS", "PPSM", "PPSX", "PPT", "PPTM", "PPTX"] },
  { id: "ebooks", label: "E-books", formats: ["AZW3", "EPUB", "FB2", "LRF", "MOBI", "PDB", "RB", "SNB", "TCR"] },
  { id: "cad", label: "CAO", formats: ["DXF"] }
];

const familyLabels = Object.fromEntries(families.map((family) => [family.id, family.label]));
const allFormats = families
  .filter((family) => family.id !== "all")
  .flatMap((family) => family.formats.map((format) => ({ format, family: family.id })))
  .filter((item, index, items) => items.findIndex((candidate) => candidate.format === item.format) === index);

const tabs = document.querySelector("[data-family-tabs]");
const results = document.querySelector("[data-format-results]");
const search = document.querySelector("[data-format-search]");
const visibleCount = document.querySelector("[data-visible-count]");
let activeFamily = "all";

function renderTabs() {
  tabs.innerHTML = families.map((family) => `
    <button class="family-tab" id="format-tab-${family.id}" type="button" role="tab" aria-controls="format-results" aria-selected="${family.id === activeFamily}" tabindex="${family.id === activeFamily ? "0" : "-1"}" data-family="${family.id}">
      ${family.label} <span>${family.id === "all" ? allFormats.length : family.formats.length}</span>
    </button>`).join("");
}

function renderFormats() {
  const query = search.value.trim().toLocaleUpperCase("fr");
  const source = activeFamily === "all"
    ? allFormats
    : allFormats.filter((item) => item.family === activeFamily);
  const filtered = source.filter((item) => item.format.includes(query) || familyLabels[item.family].toLocaleUpperCase("fr").includes(query));
  const total = filtered.length;
  visibleCount.textContent = total;
  results.setAttribute("aria-labelledby", `format-tab-${activeFamily}`);
  results.innerHTML = filtered.length
    ? filtered.slice(0, 25).map((item) => `<article class="format-item"><strong>${item.format}</strong><span>${familyLabels[item.family]}</span></article>`).join("")
    : `<p class="format-empty">Aucun format ne correspond à cette recherche.</p>`;
}

function activateFamily(family, moveFocus = false) {
  activeFamily = family;
  renderTabs();
  renderFormats();
  if (moveFocus) {
    document.querySelector(`[data-family="${family}"]`).focus();
  }
}

tabs.addEventListener("click", (event) => {
  const button = event.target.closest("[data-family]");
  if (!button) return;
  activateFamily(button.dataset.family, true);
});
tabs.addEventListener("keydown", (event) => {
  const buttons = [...tabs.querySelectorAll("[data-family]")];
  const currentIndex = buttons.indexOf(event.target.closest("[data-family]"));
  if (currentIndex < 0) return;

  let nextIndex;
  if (event.key === "ArrowRight") nextIndex = (currentIndex + 1) % buttons.length;
  if (event.key === "ArrowLeft") nextIndex = (currentIndex - 1 + buttons.length) % buttons.length;
  if (event.key === "Home") nextIndex = 0;
  if (event.key === "End") nextIndex = buttons.length - 1;
  if (nextIndex === undefined) return;

  event.preventDefault();
  activateFamily(buttons[nextIndex].dataset.family, true);
});
search.addEventListener("input", renderFormats);
renderTabs();
renderFormats();

document.querySelectorAll(".format-choice").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".format-choice").forEach((choice) => choice.classList.toggle("selected", choice === button));
    document.querySelector("[data-demo-output]").textContent = button.dataset.format;
  });
});

const demo = document.querySelector(".app-demo");
const demoButton = document.querySelector("[data-demo-convert]");
const demoStatus = document.querySelector("[data-demo-status]");
let demoTimer;
demoButton.addEventListener("click", () => {
  window.clearTimeout(demoTimer);
  demo.classList.remove("is-complete");
  demo.classList.add("is-converting");
  demoButton.disabled = true;
  demoButton.textContent = "Conversion…";
  demoStatus.innerHTML = "<i></i> Traitement sur ce Mac";
  demoTimer = window.setTimeout(() => {
    demo.classList.remove("is-converting");
    demo.classList.add("is-complete");
    demoButton.disabled = false;
    demoButton.textContent = "Reconvertir";
    demoStatus.innerHTML = "<i></i> 2 fichiers créés en 0,8 s";
  }, 1350);
});

const navToggle = document.querySelector(".nav-toggle");
const mobileNav = document.querySelector(".mobile-nav");
function closeMenu() {
  navToggle.setAttribute("aria-expanded", "false");
  mobileNav.hidden = true;
  document.body.classList.remove("nav-open");
}
navToggle.addEventListener("click", () => {
  const isOpen = navToggle.getAttribute("aria-expanded") === "true";
  navToggle.setAttribute("aria-expanded", String(!isOpen));
  mobileNav.hidden = isOpen;
  document.body.classList.toggle("nav-open", !isOpen);
});
mobileNav.querySelectorAll("a").forEach((link) => link.addEventListener("click", closeMenu));

const header = document.querySelector("[data-header]");
window.addEventListener("scroll", () => header.classList.toggle("scrolled", window.scrollY > 24), { passive: true });

const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
if (reduceMotion || !("IntersectionObserver" in window)) {
  document.querySelectorAll(".reveal").forEach((element) => element.classList.add("is-visible"));
} else {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("is-visible");
      observer.unobserve(entry.target);
    });
  }, { threshold: 0.12 });
  document.querySelectorAll(".reveal").forEach((element) => observer.observe(element));
}

document.querySelector("[data-year]").textContent = new Date().getFullYear();
