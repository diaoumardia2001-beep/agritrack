// test/unit/animals_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/models/animal.dart';

void main() {
  group('AnimalsRepository Tests', () {
    late AnimalsRepository repository;

    setUp(() {
      repository = AnimalsRepository();
    });

    test('fetchAnimals returns list of mock animals', () async {
      final animals = await repository.fetchAnimals();
      expect(animals, isNotEmpty);
      expect(animals.length, greaterThanOrEqualTo(10));
    });

    test('fetchAnimals includes all species types', () async {
      final animals = await repository.fetchAnimals();
      final types = animals.map((a) => a.type).toSet();

      expect(types.contains(AnimalType.bovin), isTrue);
      expect(types.contains(AnimalType.caprin), isTrue);
      expect(types.contains(AnimalType.ovin), isTrue);
      expect(types.contains(AnimalType.volaille), isTrue);
    });

    test('addAnimal adds a new animal and returns it', () async {
      final newAnimal = Animal(
        id: 'new_animal_123',
        name: 'Zeus',
        type: AnimalType.bovin,
        ageMonths: 14,
        weightKg: 280,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      final added = await repository.addAnimal(newAnimal);
      expect(added.id, 'new_animal_123');
      expect(added.name, 'Zeus');

      final animals = await repository.fetchAnimals();
      expect(animals.any((a) => a.id == 'new_animal_123'), isTrue);
    });
  });
}
