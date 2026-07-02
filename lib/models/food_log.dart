class FoodLog {
  final int? id;
  final DateTime date;
  final String name;
  final int calories;
  final double protein;

  const FoodLog({
    this.id,
    required this.date,
    required this.name,
    required this.calories,
    required this.protein,
  });
}
