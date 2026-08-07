# Changelog

## 1.0.1 — Distribution corrective

### Correctifs

- Corrige le crash au premier lancement sur un autre Mac en résolvant le bundle
  de traductions depuis `Contents/Resources` au lieu d’un chemin de build local.
- Ajoute un smoke test qui lance une copie isolée de l’application après avoir
  rendu le dossier `.build` inaccessible.
- Remplace les téléchargements ARM et Intel séparés par un binaire universel
  afin d’éliminer les erreurs d’architecture.

### Distribution

- Refuse les signatures ad hoc pour toute build publique.
- Vérifie Developer ID, Hardened Runtime, architectures, notarisation,
  agrafage, intégrité du DMG et ressources embarquées.
- Conserve les dSYM de release pour symboliquer les futurs rapports de crash.
- Les CTA du site ciblent exclusivement la dernière GitHub Release vérifiée.
