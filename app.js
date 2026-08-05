const families = [
  { id: "all", label: "Tous", count: 305, formats: [] },
  { id: "images", label: "Images", count: 108, formats: ["PNG", "JPG", "WEBP", "AVIF", "HEIC", "TIFF", "GIF", "BMP", "RAW", "PSD", "ICO", "EXR"] },
  { id: "audio", label: "Audio", count: 62, formats: ["MP3", "M4A", "WAV", "AIFF", "FLAC", "OGG", "OPUS", "AAC", "WMA", "AMR"] },
  { id: "video", label: "Vidéo", count: 37, formats: ["MP4", "MOV", "M4V", "WEBM", "MKV", "AVI", "MPEG", "FLV", "WMV", "3GP"] },
  { id: "documents", label: "Documents", count: 23, formats: ["PDF", "DOCX", "DOC", "ODT", "RTF", "TXT", "HTML", "CSV", "XLSX", "PPTX"] },
  { id: "archives", label: "Archives", count: 23, formats: ["ZIP", "7Z", "TAR", "RAR", "TGZ", "TBZ2", "TXZ", "JAR", "CAB", "ARJ"] },
  { id: "vectors", label: "Vecteurs", count: 20, formats: ["SVG", "EPS", "AI", "CDR", "DXF", "EMF", "WMF", "SK", "PLT", "CGM"] },
  { id: "fonts", label: "Polices", count: 16, formats: ["TTF", "OTF", "WOFF", "WOFF2", "EOT", "DFONT", "PFA", "PFB"] },
  { id: "presentations", label: "Présentations", count: 10, formats: ["PPTX", "PPT", "ODP", "PPSX", "POTX", "KEY"] },
  { id: "ebooks", label: "E-books", count: 9, formats: ["EPUB", "MOBI", "AZW3", "FB2", "LRF", "PDB", "RB", "TCR"] }
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
    <button class="family-tab" type="button" role="tab" aria-selected="${family.id === activeFamily}" data-family="${family.id}">
      ${family.label} <span>${family.count}</span>
    </button>`).join("");
}

function renderFormats() {
  const query = search.value.trim().toLocaleUpperCase("fr");
  const source = activeFamily === "all"
    ? allFormats
    : allFormats.filter((item) => item.family === activeFamily);
  const filtered = source.filter((item) => item.format.includes(query) || familyLabels[item.family].toLocaleUpperCase("fr").includes(query));
  const total = activeFamily === "all" && !query ? 305 : filtered.length;
  visibleCount.textContent = total;
  results.innerHTML = filtered.length
    ? filtered.slice(0, 25).map((item) => `<article class="format-item"><strong>${item.format}</strong><span>${familyLabels[item.family]}</span></article>`).join("")
    : `<p class="format-empty">Aucun format ne correspond à cette recherche.</p>`;
}

tabs.addEventListener("click", (event) => {
  const button = event.target.closest("[data-family]");
  if (!button) return;
  activeFamily = button.dataset.family;
  renderTabs();
  renderFormats();
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

if (/Mac/.test(navigator.platform)) {
  document.querySelector("[data-architecture-note]").textContent = "macOS 14+ · choisissez la puce de votre Mac";
}
