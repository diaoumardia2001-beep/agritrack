// test/flows/animal_lifecycle_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/app_database.dart';
import 'package:agritrack/main.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/providers/shared_preferences_provider.dart';
import 'package:agritrack/widgets/animal_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'Parcours complet: Affichage, ajout dépense, ajout animal, fermeture et réouverture avec persistance',
      (WidgetTester tester) async {
    // Initialisation d'une base de données Sembast isolée en mémoire
    final db = await AppDatabase.openInMemory(name: 'lifecycle_test.db');
    final repository = AnimalsRepository(database: Future.value(db));
    final prefs = await SharedPreferences.getInstance();

    // ─── 1. Ouvrir l'application ──────────────────────────────────────────
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animalsRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const AgriTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tableau de bord'), findsOneWidget);

    // ─── 2. Afficher la liste des animaux ────────────────────────────────
    final herdTab = find.text('Cheptel');
    expect(herdTab, findsOneWidget);
    await tester.tap(herdTab);
    await tester.pumpAndSettle();

    expect(find.text('Mon Cheptel'), findsOneWidget);
    expect(find.byType(AnimalCard), findsWidgets);
    expect(find.text('Bakary'), findsOneWidget);

    // ─── 3. Ouvrir la fiche d'un animal (Bakary) ─────────────────────────
    final bakaryCard = find.text('Bakary');
    await tester.tap(bakaryCard);
    await tester.pumpAndSettle();

    expect(find.text('Historique des dépenses'), findsOneWidget);

    // ─── 4. Ajouter une dépense valide ───────────────────────────────────
    final addExpenseFab =
        find.widgetWithText(FloatingActionButton, 'Ajouter une dépense');
    expect(addExpenseFab, findsOneWidget);
    await tester.tap(addExpenseFab);
    await tester.pumpAndSettle();

    // Remplissage du formulaire de dépense
    final labelField = find.byType(TextFormField).at(0);
    final amountField = find.byType(TextFormField).at(1);

    await tester.enterText(labelField, 'Vaccin Anthrax');
    await tester.enterText(amountField, '12500');
    await tester.pumpAndSettle();

    // Sélection catégorie Santé
    final santeChip = find.text('💊 Santé');
    await tester.tap(santeChip);
    await tester.pumpAndSettle();

    // Enregistrement
    final saveButton = find.widgetWithText(FilledButton, 'Enregistrer');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // ─── 5. Vérifier que la dépense apparaît dans la fiche ───────────────
    expect(find.text('Vaccin Anthrax'), findsOneWidget);
    // Attente de l'estompage du SnackBar
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // ─── 6. Revenir à la liste et vérifier la cohérence des données ──────
    final backButton = find.byType(BackButton);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('Mon Cheptel'), findsOneWidget);
    expect(find.text('Bakary'), findsOneWidget);

    // ─── 7. Ajouter un animal ────────────────────────────────────────────
    final addAnimalFab = find.text('Ajouter');
    expect(addAnimalFab, findsOneWidget);
    await tester.tap(addAnimalFab);
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un animal'), findsOneWidget);

    final animalNameField = find.byType(TextFormField).at(0);
    final animalAgeField = find.byType(TextFormField).at(1);
    final animalWeightField = find.byType(TextFormField).at(2);

    await tester.enterText(animalNameField, 'Zanzan');
    await tester.enterText(animalAgeField, '24');
    await tester.enterText(animalWeightField, '280.5');
    await tester.pumpAndSettle();

    final submitAnimalButton = find.text('Ajouter l\'animal');
    await tester.ensureVisible(submitAnimalButton);
    await tester.tap(submitAnimalButton);
    await tester.pumpAndSettle();

    expect(find.text('Zanzan ajouté avec succès ! 🐄'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // ─── 8. Vérifier qu'il apparaît dans le troupeau ─────────────────────
    await tester.tap(find.text('Cheptel'));
    await tester.pumpAndSettle();

    // Recherche de l'animal nouvellement créé
    final searchInput = find.byType(TextField);
    await tester.enterText(searchInput, 'Zanzan');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AnimalCard, 'Zanzan'), findsOneWidget);

    // Réinitialisation du filtre de recherche
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    // ─── 9. Simuler une fermeture et réouverture de l'application ────────
    // Démontage complet de l'arbre de widgets
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    // Réouverture avec la même base de données persistée
    final repoReopened = AnimalsRepository(database: Future.value(db));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animalsRepositoryProvider.overrideWithValue(repoReopened),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const AgriTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    // ─── 10. Vérifier que l'animal et ses dépenses sont toujours présents ─
    await tester.tap(find.text('Cheptel'));
    await tester.pumpAndSettle();

    // L'animal ajouté est toujours présent après redémarrage
    final searchInputReopened = find.byType(TextField);
    await tester.enterText(searchInputReopened, 'Zanzan');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AnimalCard, 'Zanzan'), findsOneWidget);

    // Réinitialisation du filtre
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    // L'animal modifié avec sa nouvelle dépense est toujours présent
    expect(find.text('Bakary'), findsOneWidget);
    await tester.tap(find.text('Bakary'));
    await tester.pumpAndSettle();

    // La dépense ajoutée avant la fermeture est bien conservée
    expect(find.text('Vaccin Anthrax'), findsOneWidget);
  });
}
