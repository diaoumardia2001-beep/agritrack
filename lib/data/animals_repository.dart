// lib/data/animals_repository.dart
import '../models/animal.dart';
import '../models/expense.dart';

class AnimalsRepository {
  static final List<Animal> _animals = [
    Animal(
      id: 'a001',
      name: 'Bakary',
      type: AnimalType.bovin,
      ageMonths: 36,
      weightKg: 320.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e001',
          label: 'Sac de foin 50kg',
          amount: 8500,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e002',
          label: 'Vaccination FMD',
          amount: 15000,
          date: DateTime(2026, 9, 15),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e003',
          label: 'Complément minéral',
          amount: 6200,
          date: DateTime(2026, 9, 5),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2026, 1, 15),
    ),
    Animal(
      id: 'a002',
      name: 'Fanta',
      type: AnimalType.bovin,
      ageMonths: 24,
      weightKg: 265.0,
      healthStatus: HealthStatus.aSurveiller,
      expenses: [
        Expense(
          id: 'e004',
          label: 'Consultation vétérinaire',
          amount: 12000,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e005',
          label: 'Antibiotiques',
          amount: 9500,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e006',
          label: 'Aliment concentré',
          amount: 7800,
          date: DateTime(2026, 9, 20),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2026, 3, 22),
    ),
    Animal(
      id: 'a003',
      name: 'Koné',
      type: AnimalType.bovin,
      ageMonths: 48,
      weightKg: 410.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e007',
          label: 'Foin et paille',
          amount: 10500,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e008',
          label: 'Vermifuge',
          amount: 4500,
          date: DateTime(2026, 9, 10),
          category: ExpenseCategory.sante,
        ),
      ],
      createdAt: DateTime(2025, 8, 10),
    ),
    Animal(
      id: 'a004',
      name: 'Mamadou',
      type: AnimalType.caprin,
      ageMonths: 18,
      weightKg: 32.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e009',
          label: 'Mélange grain/son',
          amount: 2200,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e010',
          label: 'Vaccin PPR',
          amount: 3500,
          date: DateTime(2026, 8, 20),
          category: ExpenseCategory.sante,
        ),
      ],
      createdAt: DateTime(2026, 5, 3),
    ),
    Animal(
      id: 'a005',
      name: 'Awa',
      type: AnimalType.caprin,
      ageMonths: 12,
      weightKg: 18.0,
      healthStatus: HealthStatus.malade,
      expenses: [
        Expense(
          id: 'e011',
          label: 'Traitement diarrhée',
          amount: 7500,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e012',
          label: 'Sérum réhydratant',
          amount: 4200,
          date: DateTime(2026, 9, 28),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e013',
          label: 'Fourrage vert',
          amount: 1500,
          date: DateTime(2026, 9, 25),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2026, 7, 18),
    ),
    Animal(
      id: 'a006',
      name: 'Souleymane',
      type: AnimalType.caprin,
      ageMonths: 30,
      weightKg: 45.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e014',
          label: 'Bloc minéral lécheur',
          amount: 2800,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2025, 12, 1),
    ),
    Animal(
      id: 'a007',
      name: 'Rokia',
      type: AnimalType.ovin,
      ageMonths: 22,
      weightKg: 55.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e015',
          label: 'Son de maïs 25kg',
          amount: 3800,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e016',
          label: 'Tonte et soin sabots',
          amount: 5000,
          date: DateTime(2026, 9, 12),
          category: ExpenseCategory.autre,
        ),
      ],
      createdAt: DateTime(2026, 2, 28),
    ),
    Animal(
      id: 'a008',
      name: 'Ibrahim',
      type: AnimalType.ovin,
      ageMonths: 14,
      weightKg: 38.0,
      healthStatus: HealthStatus.aSurveiller,
      expenses: [
        Expense(
          id: 'e017',
          label: 'Bilan sanguin',
          amount: 18000,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e018',
          label: 'Pâture supplémentaire',
          amount: 4200,
          date: DateTime(2026, 9, 18),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2026, 6, 10),
    ),
    Animal(
      id: 'a009',
      name: 'Adjoua',
      type: AnimalType.ovin,
      ageMonths: 60,
      weightKg: 78.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e019',
          label: 'Foin de légumineuse',
          amount: 5600,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2024, 11, 5),
    ),
    Animal(
      id: 'a010',
      name: 'Cocorico',
      type: AnimalType.volaille,
      ageMonths: 6,
      weightKg: 2.8,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e020',
          label: 'Aliment pondeuse 10kg',
          amount: 5200,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e021',
          label: 'Vaccination Newcastle',
          amount: 2500,
          date: DateTime(2026, 9, 8),
          category: ExpenseCategory.sante,
        ),
      ],
      createdAt: DateTime(2026, 8, 5),
    ),
    Animal(
      id: 'a011',
      name: 'Perlita',
      type: AnimalType.volaille,
      ageMonths: 4,
      weightKg: 1.9,
      healthStatus: HealthStatus.malade,
      expenses: [
        Expense(
          id: 'e022',
          label: 'Traitement coccidiose',
          amount: 3800,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e023',
          label: 'Probiotique avicole',
          amount: 2100,
          date: DateTime(2026, 9, 30),
          category: ExpenseCategory.sante,
        ),
      ],
      createdAt: DateTime(2026, 9, 1),
    ),
    Animal(
      id: 'a012',
      name: 'Djata',
      type: AnimalType.bovin,
      ageMonths: 8,
      weightKg: 115.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e024',
          label: 'Lait maternel substitut',
          amount: 12000,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e025',
          label: 'Boucle auriculaire + enregistrement',
          amount: 3500,
          date: DateTime(2026, 9, 2),
          category: ExpenseCategory.autre,
        ),
      ],
      createdAt: DateTime(2026, 9, 15),
    ),
  ];

  /// Simule un chargement asynchrone depuis une base de données
  Future<List<Animal>> fetchAnimals() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return List.unmodifiable(_animals);
  }

  /// Ajoute un animal à la liste in-memory
  Future<Animal> addAnimal(Animal animal) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _animals.add(animal);
    return animal;
  }
}
