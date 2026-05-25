# Cahier des charges — Application de tri de photos macOS

---

## 1. Contexte & objectifs

Aucun outil gratuit sur macOS ne permet de visualiser et trier rapidement plusieurs milliers de photos depuis un répertoire source vers des répertoires cibles. Cette application comble ce manque avec une approche minimaliste et performante.

**Utilisateur cible :** photographe amateur ou professionnel cherchant à trier ses imports rapidement, sans abonnement ni compte en ligne. Profil non-technique — l'interface doit être intuitive dès le premier lancement, sans documentation.

### Indicateurs clés

| Paramètre | Valeur |
|---|---|
| Photos source max | 5 000 |
| Plateforme cible | macOS |
| Coût utilisateur | Gratuit |
| Formats supportés | JPG, PNG, HEIC, RAW |

---

## 2. Exigences fonctionnelles

### Incontournables (MUST)

| ID | Exigence |
|---|---|
| F-01 | Choisir un répertoire source via un sélecteur natif macOS |
| F-02 | Afficher les photos en grille avec miniatures (lazy loading pour 5 000 images) |
| F-03 | Créer un ou plusieurs répertoires cibles (nommés librement) |
| F-04 | Sélectionner une ou plusieurs photos (clic, Cmd+clic, Shift+clic) |
| F-05 | Déplacer les photos sélectionnées vers un répertoire cible (drag & drop ou bouton) |
| F-06 | Rafraîchir la grille source après chaque déplacement (photos déplacées disparaissent) |
| F-07 | Annuler la dernière action (Cmd+Z) |

### Utiles (SHOULD)

| ID | Exigence |
|---|---|
| F-08 | Prévisualisation plein écran au double-clic ou barre espace |
| F-09 | Trier la grille par date, nom, taille |
| F-10 | Afficher le nom de fichier et la date EXIF au survol |
| F-11 | Sauvegarder la session (répertoires cibles) entre deux lancements |

---

## 3. Contraintes de performance

| ID | Objectif |
|---|---|
| P-01 | Affichage des 100 premières miniatures en moins de 2 secondes après sélection du répertoire |
| P-02 | Chargement lazy : les miniatures hors écran ne sont générées qu'à l'approche du scroll |
| P-03 | Miniatures mises en cache sur disque (~200×200 px) pour éviter la re-génération |
| P-04 | Déplacement de 100 fichiers en moins de 3 secondes |
| P-05 | Utilisation mémoire inférieure à 300 Mo quelle que soit la taille du répertoire source |
| P-06 | Support des fichiers HEIC (natif macOS) et RAW courants (Canon CR2, Nikon NEF, Sony ARW) |

---

## 4. UX & Interface

### Principes directeurs

- Fenêtre unique — pas de multiples panneaux ou onglets complexes. Layout en deux zones : grille source (gauche/centre) + panneau cibles (droite).
- Zéro configuration requise au démarrage : un seul bouton "Ouvrir un dossier source" suffit.
- Retour visuel immédiat : la sélection est visible, le déplacement animé, le undo confirmé.

### Interactions clés

| ID | Interaction |
|---|---|
| UX-01 | Drag & drop des photos sélectionnées vers un répertoire cible dans le panneau latéral |
| UX-02 | Clic sur un répertoire cible + bouton "Déplacer ici" comme alternative au drag |
| UX-03 | Raccourcis clavier : Cmd+A (tout sélectionner), Espace (prévisualisation), Cmd+Z (annuler) |
| UX-04 | Badge de comptage sur chaque répertoire cible (ex : "Vacances — 23 photos") |
| UX-05 | Barre de statut en bas : nombre de photos sélectionnées / total restant dans la source |

---

## 5. Stack technique recommandée

Le choix est guidé par la simplicité de distribution sur macOS, la performance native, et la facilité de maintenance. Application desktop locale, aucune dépendance réseau.

### Option A — Electron + React
Distribution simple (.dmg), accès Node.js au filesystem, UI web familière. Idéal si profil web dev.

### Option B — Swift + SwiftUI ★ Recommandée
Performance native maximale, support HEIC intégré, App Store possible. Idéal pour les 5 000 photos. Recommandé si profil macOS.

### Option C — Python + Tkinter / PyQt
Développement rapide, multiplateforme. Performances moindres sur grandes collections. Option prototypage.

### Recommandation

**Swift + SwiftUI** est le choix optimal : performances, intégration macOS native (Quick Look, EXIF, HEIC), distribution via notarisation Apple sans App Store obligatoire.

---

## 6. Roadmap de développement

### Phase 1 — MVP fonctionnel (~2 semaines)
Sélection répertoire source · Grille avec lazy loading · Création répertoires cibles · Sélection multi-photos · Déplacement · Undo basique

### Phase 2 — Performance & polish (~1 semaine)
Cache miniatures sur disque · Tri de la grille · Prévisualisation plein écran · Tooltips EXIF · Raccourcis clavier complets

### Phase 3 — Confort d'utilisation (~1 semaine)
Sauvegarde session · Support RAW étendu · Drag & drop depuis Finder · Badge compteurs · Barre de statut

### Hors scope v1 (évolutions futures)
Filtrage par date/tag EXIF · Détection de doublons · Export vers cloud · Mode renommage en lot

---

## 7. Risques & mitigations

| Niveau | Risque | Mitigation |
|---|---|---|
| Élevé | Performance sur 5 000 photos | Lazy loading strict + cache miniatures + virtualisation de la grille |
| Élevé | Perte de fichiers lors d'un déplacement | Opération filesystem atomique + undo multi-niveaux + confirmation si > 50 fichiers |
| Moyen | Support des formats RAW exotiques | Utiliser ImageIO (macOS natif) qui gère ~30 formats RAW |
| Moyen | Permissions macOS (accès disque complet) | Utiliser les API sandbox-friendly NSOpenPanel / bookmarks sécurisés |
| Faible | Distribution sans App Store | Notarisation Apple gratuite via Xcode — .dmg signé et validé |
