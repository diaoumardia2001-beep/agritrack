# Journal des modifications (CHANGELOG)

Toutes les modifications notables apportées au projet **AgriTrack** sont documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/), et ce projet adhère au [Semantic Versioning](https://semver.org/lang/fr/).

---

## [1.0.0] - 2026-10-01

### Ajouté
- 🚀 **Version initiale Production-Ready** certifiée pour petits éleveurs en Côte d'Ivoire.
- 📱 **5 Écrans complets et interconnectés** :
  - `DashboardScreen` : KPIs temps réel, alertes sanitaires, camembert des espèces et résumé financier en Francs CFA (FCFA).
  - `AnimalListScreen` : Vue du cheptel avec recherche en temps réel, filtres multi-critères (espèces, santé) et tri dynamique.
  - `AnimalDetailScreen` : Fiche détaillée de l'animal, badge d'état, historique des dépenses et formulaire d'ajout rapide de frais.
  - `AddAnimalScreen` : Formulaire de création d'animal avec validation stricte des données et sélecteurs visuels.
  - `SettingsScreen` : Gestion du thème dynamique (clair/sombre) et changement de langue (Français/Anglais).
- 🌍 **Internationalisation (i18n)** : Support complet FR (Côte d'Ivoire/France) et EN (US) avec sélecteur de langue interactif.
- ♿ **Accessibilité & Sémantique** : `Semantics` tags, tooltips et descriptions pour lecteurs d'écran.
- 🧪 **Suite complète de tests automatisés** :
  - 16 tests unitaires (`models_test.dart`, `animals_repository_test.dart`, `providers_test.dart`).
  - 5 tests de widgets (`dashboard_screen_test.dart`, `animal_card_test.dart`, `settings_screen_test.dart`, `search_filter_bar_test.dart`, `health_status_badge_test.dart`).
  - 2 tests d'intégration End-to-End (`app_navigation_test.dart`, `add_animal_flow_test.dart`).
- 🤖 **Pipeline CI/CD GitHub Actions** : Linting automatique sans warnings (`flutter analyze`), exécution des tests avec couverture et builds Web/Android.

---

## [0.2.0] - 2026-09-20

### Ajouté
- 📦 Intégration de **Riverpod 2.5** pour la gestion d'état réactive (`AsyncNotifierProvider`, `StateNotifierProvider`).
- 💰 Système complet de gestion des dépenses par animal avec catégorisation (`Alimentation`, `Santé & Vétérinaire`, `Autre`).
- 🎨 Design System Material 3 avec palette agronomique personnalisée (Vert Émeraude, Terre Noire, Or).

### Modifié
- Refactorisation du repository pour simuler des délais asynchrones d'API / base de données locale.
- Optimisation des performances à 60 FPS avec l'usage strict de widgets `const`.

---

## [0.1.0] - 2026-09-10

### Ajouté
- 🏗️ Initialisation de la structure du projet Flutter (Clean Architecture).
- 🐂 Définition des modèles de données fondamentaux (`Animal`, `Expense`, `AnimalType`, `HealthStatus`, `ExpenseCategory`).
- 📊 Création de la première base de données mockée de 12 animaux typiques de l'élevage ouest-africain.
