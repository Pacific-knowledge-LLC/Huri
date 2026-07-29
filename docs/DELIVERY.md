# Delivery policy

## Flux de changement

Chaque changement part d’une branche courte, passe par une pull request et doit
obtenir le statut `Swift quality and distributable` avant fusion. Les anciennes
exécutions d’une même branche sont annulées automatiquement.

La branche `main` doit être protégée avec :

- pull request obligatoire, sans push direct ;
- branche à jour avant fusion ;
- contrôle requis `Swift quality and distributable` ;
- résolution des conversations obligatoire ;
- force-push et suppression interdits ;
- administrateurs soumis aux mêmes règles.

Le workflow CI a seulement un droit de lecture. Le workflow Release n’obtient
un droit d’écriture sur le contenu que dans le job qui publie la GitHub Release.
Le jeton du tap Homebrew est limité à son dépôt.

## Gates

| Gate | Preuve |
|---|---|
| Source | `swift format lint --strict`, scripts shell valides, scan de secrets |
| Dépendances | `Package.resolved` inchangé après résolution |
| Fonctionnel | tests unitaires et d’intégration Swift |
| Distribution | builds Debug/Release, app assemblée, ressources FR/EN, signature |
| Expérience | onboarding et visite guidée, FR/EN, clair/sombre, fenêtre compacte |
| Release | tag cohérent avec `VERSION`, identités de signature et clés présentes |

Un gate rouge arrête la livraison. Les exceptions documentent le risque, le
propriétaire, la date d’expiration et le plan de retour.

## Definition of Done

Une carte est terminée lorsque son code, ses tests et sa documentation sont
présents, que `make verify` passe, que le parcours concerné a été observé dans
l’app assemblée et que la preuve externe demandée existe. Un workflow seulement
écrit ne prouve pas une publication : App Store Connect, la GitHub Release et le
cask doivent confirmer le résultat.
