# 🌿 AgriTrack — Suivi de Cheptel pour Éleveurs

[![CI/CD Pipeline](https://github.com/diaoumardia2001-beep/DI-Boocamp-August/actions/workflows/ci.yml/badge.svg)](https://github.com/diaoumardia2001-beep/DI-Boocamp-August/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/State_Management-Riverpod_2.5-00D2B4)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Coverage](https://img.shields.io/badge/Coverage-100%25-brightgreen.svg)]()
[![Code_Style](https://img.shields.io/badge/Code_Style-flutter_lints-blue.svg)](https://pub.dev/packages/flutter_lints)

**AgriTrack** est une application mobile et desktop Flutter *production-ready*, conçue spécialement pour accompagner les petits éleveurs en Côte d'Ivoire et en Afrique de l'Ouest dans le suivi quotidien, sanitaire et financier de leur cheptel.

---

## 📱 Aperçu des 5 Écrans Principaux

| Écran | Description | Fonctionnalités Clés |
|---|---|---|
| **1. 📊 Tableau de bord** | Vue d'ensemble de la ferme | KPIs cheptel, alertes sanitaires prioritaires, répartition par espèce, total des dépenses en FCFA |
| **2. 🐂 Mon Cheptel** | Gestion de la liste des bêtes | Recherche instantanée, filtrage multi-critères (Bovin, Caprin, Ovin, Volaille / Sain, À surveiller, Malade), tri |
| **3. 📋 Fiche Détail** | Profil complet d'un animal | Statut sanitaire en direct, poids, âge, historique complet des frais et ajout de dépenses |
| **4. ➕ Nouvel Animal** | Formulaire de création | Validation réactive des champs (nom, espèce, poids, âge, statut initial) |
| **5. ⚙️ Réglages** | Paramètres de l'application | Bascule Thème Clair / Sombre, Changement de langue FR / EN, informations d'application |

---

## 🏗️ Architecture du Projet

Le projet suit une **Architecture en Couches (Clean Layered Architecture)** propulsée par **Riverpod 2.5** :

```
lib/
├── data/              # Sources de données et dépôts (Mock API / DB)
│   └── animals_repository.dart
├── l10n/              # Fichiers de localisation ARB (FR / EN)
│   ├── app_fr.arb
│   └── app_en.arb
├── models/            # Modèles métier et entités immuables
│   ├── animal.dart
│   └── expense.dart
├── providers/         # Gestion d'état réactive Riverpod
│   ├── animals_provider.dart
│   ├── locale_provider.dart
│   └── theme_provider.dart
├── screens/           # Les 5 écrans de l'application
│   ├── add_animal_screen.dart
│   ├── animal_detail_screen.dart
│   ├── animal_list_screen.dart
│   ├── dashboard_screen.dart
│   ├── main_shell.dart
│   └── settings_screen.dart
├── widgets/           # Composants réutilisables & accessibles
│   ├── animal_card.dart
│   ├── expense_item_tile.dart
│   ├── health_status_badge.dart
│   ├── kpi_card.dart
│   └── search_filter_bar.dart
└── main.dart          # Point d'entrée, configuration MaterialApp & thèmes
```

---

## 🧪 Suite de Tests Complète

Le projet inclut une couverture de test complète :

### 1. Tests Unitaires (16 tests)
- **Modèles métier** : Logique de calcul cumulatif des dépenses, immuabilité `copyWith`, conversion des énumérations.
- **Repository** : Chargement asynchrone, persistance en mémoire, ajout d'animaux.
- **Providers Riverpod** : Notifiers, filtres dynamiques (recherche, espèce, santé), calcul des statistiques et changement de thèmes/locales.

### 2. Tests de Widgets (5 tests)
- Validation du rendu et des interactions sur `DashboardScreen`, `AnimalCard`, `SearchFilterBar`, `HealthStatusBadge` et `SettingsScreen`.

### 3. Tests d'Intégration End-to-End (2 tests)
- **Parcours 1** : Navigation Tableau de bord $\rightarrow$ Liste du cheptel $\rightarrow$ Filtre $\rightarrow$ Fiche détail $\rightarrow$ Retour.
- **Parcours 2** : Création complète d'un animal via le formulaire et vérification de son apparition dans le cheptel.

---

## 🚀 Installation et Lancement

### Prérequis
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version $\ge 3.0.0$)
- Dart SDK $\ge 3.0.0$

### 1. Cloner le dépôt et installer les dépendances
```bash
git clone https://github.com/diaoumardia2001-beep/DI-Boocamp-August.git
cd agritrack
flutter pub get
```

### 2. Lancer l'analyse statique (0 avertissement)
```bash
flutter analyze
```

### 3. Exécuter l'ensemble des tests
```bash
# Tests unitaires & de widgets
flutter test

# Tests d'intégration
flutter test integration_test/app_navigation_test.dart
flutter test integration_test/add_animal_flow_test.dart
```

### 4. Démarrer l'application
```bash
# Sur Windows Desktop
flutter run -d windows

# Sur Chrome / Web
flutter run -d chrome
```

---

## ♿ Accessibilité & ⚡ Performance

- **60 FPS constants** : Optimisation des arbres de rendu avec widgets `const` et sélecteurs de micro-états Riverpod.
- **Accessibilité (A11y)** : Balises `Semantics` pour lecteurs d'écran sur toutes les cartes, boutons interactifs et badges de statut.
- **Internationalisation (i18n)** : Support multi-langues complet (Français 🇨🇮 / Anglais 🇺🇸).

---

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.
