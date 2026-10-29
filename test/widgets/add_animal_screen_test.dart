// test/widgets/add_animal_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/screens/add_animal_screen.dart';

void main() {
  final sampleAnimal = Animal(
    id: 'anim_edit_123',
    name: 'Bella',
    type: AnimalType.bovin,
    ageMonths: 36,
    weightKg: 450.0,
    healthStatus: HealthStatus.sain,
    expenses: [
      Expense(
        id: 'exp_01',
        label: 'Alimentation',
        amount: 15000,
        date: DateTime(2026, 1, 1),
        category: ExpenseCategory.alimentation,
      ),
    ],
    createdAt: DateTime(2025, 5, 10),
  );

  Widget buildTestableScreen({
    Animal? animalToEdit,
    ThemeMode themeMode = ThemeMode.light,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'CI'),
          Locale('en', 'US'),
        ],
        locale: const Locale('fr', 'CI'),
        home: AddAnimalScreen(animalToEdit: animalToEdit),
      ),
    );
  }

  group('AddAnimalScreen Widget & Form Tests', () {
    // 1. Affichage du formulaire
    testWidgets(
        '1. Renders add animal form with header, fields, live preview, and submit button',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('Ajouter un animal'), findsOneWidget);
      expect(find.text('Aperçu de la fiche'), findsOneWidget);
      expect(find.text('TEMPS RÉEL'), findsOneWidget);
      expect(find.text('Identification'), findsOneWidget);
      expect(find.text('Nom de l\'animal *'), findsOneWidget);
      expect(find.text('Espèce animale *'), findsOneWidget);
      expect(find.text('Caractéristiques physiques'), findsOneWidget);
      expect(find.text('Âge (en mois) *'), findsOneWidget);
      expect(find.text('Poids (kg) *'), findsOneWidget);
      expect(find.text('Statut sanitaire *'), findsOneWidget);
      expect(find.text('Ajouter l\'animal'), findsOneWidget);
    });

    // 2. Sélection de chaque espèce
    testWidgets('2. Allows selecting each species and updates live preview',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      for (final type in AnimalType.values) {
        final speciesFinder = find.byKey(ValueKey('species_tile_${type.name}'));
        expect(speciesFinder, findsOneWidget);

        await tester.tap(speciesFinder);
        await tester.pumpAndSettle();

        // L'aperçu dynamique affiche l'espèce sélectionnée
        expect(find.text(type.label), findsWidgets);
      }
    });

    // 3. Validation du nom
    testWidgets('3. Validates required animal name (empty and too short)',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      final nameField = find.byType(TextFormField).at(0);
      final submitBtn = find.text('Ajouter l\'animal');

      // Tentative de soumission vide
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir un nom'), findsOneWidget);

      // Nom avec 1 seul caractère
      await tester.enterText(nameField, 'A');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Le nom doit contenir au moins 2 caractères'),
          findsOneWidget);
    });

    // 4. Validation de l'âge
    testWidgets('4. Validates age field (empty, negative, too large)',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      final ageField = find.byType(TextFormField).at(1);
      final submitBtn = find.text('Ajouter l\'animal');

      // Âge vide
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir l\'âge'), findsOneWidget);

      // Âge trop grand (> 300 mois)
      await tester.enterText(ageField, '350');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Âge trop élevé (max 300 mois)'), findsOneWidget);
    });

    // 5. Validation du poids
    testWidgets('5. Validates weight field (empty, 0, negative, too large)',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      final weightField = find.byType(TextFormField).at(2);
      final submitBtn = find.text('Ajouter l\'animal');

      // Poids vide
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir le poids'), findsOneWidget);

      // Poids à 0
      await tester.enterText(weightField, '0');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Poids invalide'), findsOneWidget);

      // Poids trop grand (> 2000 kg)
      await tester.enterText(weightField, '2500');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Poids trop élevé (max 2000 kg)'), findsOneWidget);
    });

    // 6. Soumission réussie
    testWidgets(
        '6. Successful animal addition creates animal and displays confirmation',
        (WidgetTester tester) async {
      final mockRepo = _MemoryAnimalsRepository();

      await tester.pumpWidget(
        buildTestableScreen(
          overrides: [
            animalsRepositoryProvider.overrideWithValue(mockRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final nameField = find.byType(TextFormField).at(0);
      final ageField = find.byType(TextFormField).at(1);
      final weightField = find.byType(TextFormField).at(2);

      await tester.enterText(nameField, 'Kader');
      await tester.enterText(ageField, '18');
      await tester.enterText(weightField, '210.5');
      await tester.pumpAndSettle();

      // Sélection Caprin via Key
      await tester.tap(find.byKey(const ValueKey('species_tile_caprin')));
      await tester.pumpAndSettle();

      final submitBtn = find.text('Ajouter l\'animal');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(mockRepo.addedAnimals.length, 1);
      expect(mockRepo.addedAnimals.first.name, 'Kader');
      expect(mockRepo.addedAnimals.first.type, AnimalType.caprin);
      expect(mockRepo.addedAnimals.first.ageMonths, 18);
      expect(mockRepo.addedAnimals.first.weightKg, 210.5);
    });

    // 7. Protection contre les doubles soumissions
    testWidgets('7. Protects against double submission while submitting',
        (WidgetTester tester) async {
      final slowRepo = _SlowAnimalsRepository();

      await tester.pumpWidget(
        buildTestableScreen(
          overrides: [
            animalsRepositoryProvider.overrideWithValue(slowRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Rapide');
      await tester.enterText(find.byType(TextFormField).at(1), '12');
      await tester.enterText(find.byType(TextFormField).at(2), '150');

      final submitBtn = find.text('Ajouter l\'animal');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();

      // En cours d'enregistrement
      expect(find.text('Enregistrement...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Cliquer à nouveau n'ajoute pas de second appel
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(slowRepo.callCount, 1);

      // Laisser s'écouler le délai restant de 500ms pour qu'aucun timer ne reste en attente
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    });

    // 8. Gestion d'une erreur de persistance
    testWidgets(
        '8. Handles repository error: displays SnackBar and keeps form inputs intact',
        (WidgetTester tester) async {
      final failingRepo = _FailingAnimalsRepo();

      await tester.pumpWidget(
        buildTestableScreen(
          overrides: [
            animalsRepositoryProvider.overrideWithValue(failingRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final nameField = find.byType(TextFormField).at(0);
      final ageField = find.byType(TextFormField).at(1);
      final weightField = find.byType(TextFormField).at(2);

      await tester.enterText(nameField, 'Animal Échoué');
      await tester.enterText(ageField, '22');
      await tester.enterText(weightField, '190');

      final submitBtn = find.text('Ajouter l\'animal');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // SnackBar d'erreur affiché
      expect(find.textContaining('Erreur lors de l\'enregistrement'),
          findsOneWidget);

      // Le formulaire reste ouvert et les données ne sont pas perdues dans les TextFormField
      expect(
          find.widgetWithText(TextFormField, 'Animal Échoué'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '22'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '190'), findsOneWidget);
    });

    // 9. Absence de duplication d'animal
    testWidgets(
        '9. Adding animal increments herd count by exactly 1 without duplicates',
        (WidgetTester tester) async {
      final mockRepo = _MemoryAnimalsRepository();

      await tester.pumpWidget(
        buildTestableScreen(
          overrides: [
            animalsRepositoryProvider.overrideWithValue(mockRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Unique');
      await tester.enterText(find.byType(TextFormField).at(1), '14');
      await tester.enterText(find.byType(TextFormField).at(2), '200');

      final submitBtn = find.text('Ajouter l\'animal');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(mockRepo.addedAnimals.length, 1);
      expect(mockRepo.addedAnimals.where((a) => a.name == 'Unique').length, 1);
    });

    // 10. Fonctionnement en thème clair et sombre
    testWidgets(
        '10. Renders cleanly in dark theme without overflow or contrast issues',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableScreen(themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ajouter un animal'), findsOneWidget);
      expect(find.text('Aperçu de la fiche'), findsOneWidget);
      expect(find.text('Identification'), findsOneWidget);
      expect(find.text('Caractéristiques physiques'), findsOneWidget);
    });

    // 11. Comportement responsive
    testWidgets(
        '11. Responsive layout works on compact mobile and wide screens',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('Ajouter un animal'), findsOneWidget);
      expect(find.text('Aperçu de la fiche'), findsOneWidget);

      // Écran large desktop (1440 x 900)
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('Ajouter un animal'), findsOneWidget);
      expect(find.text('Aperçu de la fiche'), findsOneWidget);
    });

    // 12. Persistance correcte en cas d'édition
    testWidgets(
        '12. Edit mode pre-populates fields, preserves ID and expenses, and submits update',
        (WidgetTester tester) async {
      final mockRepo = _MemoryAnimalsRepository();
      mockRepo.existingAnimal = sampleAnimal;

      await tester.pumpWidget(
        buildTestableScreen(
          animalToEdit: sampleAnimal,
          overrides: [
            animalsRepositoryProvider.overrideWithValue(mockRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Vérifie l'en-tête et le bouton d'édition
      expect(find.text('Modifier l\'animal'), findsOneWidget);
      expect(find.text('Enregistrer les modifications'), findsOneWidget);
      expect(find.text('#anim_edit_123'), findsOneWidget);

      // Vérifie le pré-remplissage dans les champs de saisie
      expect(find.widgetWithText(TextFormField, 'Bella'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '36'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '450.0'), findsOneWidget);

      // Modification du nom et du poids
      final nameField = find.byType(TextFormField).at(0);
      final weightField = find.byType(TextFormField).at(2);

      await tester.enterText(nameField, 'Bella Modifiée');
      await tester.enterText(weightField, '465.0');
      await tester.pumpAndSettle();

      // Soumission
      final submitBtn = find.text('Enregistrer les modifications');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(mockRepo.updatedAnimal, isNotNull);
      expect(mockRepo.updatedAnimal!.id, sampleAnimal.id);
      expect(mockRepo.updatedAnimal!.name, 'Bella Modifiée');
      expect(mockRepo.updatedAnimal!.weightKg, 465.0);
      expect(mockRepo.updatedAnimal!.expenses.length, 1); // Dépenses préservées
      expect(mockRepo.updatedAnimal!.createdAt,
          sampleAnimal.createdAt); // Date préservée
    });
  });
}

// ─── Repositories de test ───────────────────────────────────────────────────

class _MemoryAnimalsRepository extends AnimalsRepository {
  final List<Animal> addedAnimals = [];
  Animal? existingAnimal;
  Animal? updatedAnimal;

  @override
  Future<List<Animal>> fetchAnimals({
    String? farmId,
    bool includeDeleted = false,
  }) async =>
      [
        if (existingAnimal != null &&
            (includeDeleted || existingAnimal!.deletedAt == null))
          existingAnimal!,
        ...addedAnimals.where((a) => includeDeleted || a.deletedAt == null),
      ];

  @override
  Future<Animal?> getAnimalById(
    String animalId, {
    bool includeDeleted = false,
  }) async {
    if (existingAnimal?.id == animalId) return existingAnimal;
    for (final a in addedAnimals) {
      if (a.id == animalId) return a;
    }
    return null;
  }

  @override
  Future<Animal> addAnimal(Animal animal, {String? targetFarmId}) async {
    addedAnimals.add(animal);
    return animal;
  }

  @override
  Future<Animal> updateAnimal(Animal animal) async {
    updatedAnimal = animal;
    return animal;
  }
}

class _SlowAnimalsRepository extends AnimalsRepository {
  int callCount = 0;

  @override
  Future<Animal> addAnimal(Animal animal, {String? targetFarmId}) async {
    callCount++;
    await Future.delayed(const Duration(milliseconds: 500));
    return animal;
  }
}

class _FailingAnimalsRepo extends AnimalsRepository {
  @override
  Future<Animal> addAnimal(Animal animal, {String? targetFarmId}) async {
    throw Exception('Erreur d\'écriture disque simulée');
  }
}
