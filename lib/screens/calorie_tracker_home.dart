import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/food_log.dart';

class CalorieTrackerHome extends StatefulWidget {
  const CalorieTrackerHome({super.key});

  @override
  State<CalorieTrackerHome> createState() => _CalorieTrackerHomeState();
}

class _CalorieTrackerHomeState extends State<CalorieTrackerHome> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();

  Box get _box => Hive.box('food_logs');

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  FoodLog? _foodLogFromHive(dynamic value) {
    if (value is Map) {
      final dateValue = value['date'];
      final name = value['name'];
      final calories = value['calories'];
      final protein = value['protein'];

      if (dateValue is int && name is String && calories is int && protein is double) {
        return FoodLog(
          date: DateTime.fromMillisecondsSinceEpoch(dateValue),
          name: name,
          calories: calories,
          protein: protein,
        );
      }
    }
    return null;
  }

  List<FoodLog> _todayEntries(Box box) {
    final today = DateTime.now();
    final entries = box.values
        .map(_foodLogFromHive)
        .where((entry) => entry != null)
        .cast<FoodLog>()
        .where((entry) => _isSameDate(entry.date, today))
        .toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  int _todayCalories(List<FoodLog> entries) {
    return entries.fold(0, (sum, entry) => sum + entry.calories);
  }

  double _todayProtein(List<FoodLog> entries) {
    return entries.fold(0.0, (sum, entry) => sum + entry.protein);
  }

  Future<void> _addFoodEntry({
    required String name,
    required int calories,
    required double protein,
  }) async {
    await _box.add({
      'date': DateTime.now().millisecondsSinceEpoch,
      'name': name,
      'calories': calories,
      'protein': protein,
    });
  }

  void _showAddFoodBottomSheet() {
    _nameController.clear();
    _caloriesController.clear();
    _proteinController.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Food Entry',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Food name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calories',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proteinController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Protein (g)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final dialogContext = context;
                  final name = _nameController.text.trim();
                  final calories = int.tryParse(_caloriesController.text.trim());
                  final protein = double.tryParse(_proteinController.text.trim());

                  if (name.isEmpty || calories == null || protein == null) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter valid food name, calories, and protein.'),
                      ),
                    );
                    return;
                  }

                  await _addFoodEntry(
                    name: name,
                    calories: calories,
                    protein: protein,
                  );

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save entry'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calories Tracker'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<Box>(
          valueListenable: _box.listenable(),
          builder: (context, box, _) {
            final todayEntries = _todayEntries(box);
            final totalCalories = _todayCalories(todayEntries);
            final totalProtein = _todayProtein(todayEntries);

            return Column(
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today Summary',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSummaryTile(
                              title: 'Calories',
                              value: '$totalCalories kcal',
                            ),
                            _buildSummaryTile(
                              title: 'Protein',
                              value: '${totalProtein.toStringAsFixed(1)} g',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: todayEntries.isEmpty
                      ? Center(
                          child: Text(
                            'No food entries yet for today.',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: todayEntries.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = todayEntries[index];
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                title: Text(entry.name),
                                subtitle: Text(
                                  '${entry.calories} kcal · ${entry.protein.toStringAsFixed(1)} g protein',
                                ),
                                trailing: Text(
                                  _formatTime(entry.date),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFoodBottomSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryTile({required String title, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
