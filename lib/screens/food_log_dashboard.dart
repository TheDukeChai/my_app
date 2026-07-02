import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/food_log.dart';

class FoodLogDashboard extends StatefulWidget {
  const FoodLogDashboard({super.key});

  @override
  State<FoodLogDashboard> createState() => _FoodLogDashboardState();
}

class _FoodLogDashboardState extends State<FoodLogDashboard> {
  Box get _box => Hive.box('food_logs');

  FoodLog? _foodLogFromHive(int key, dynamic value) {
    if (value is Map) {
      final dateValue = value['date'];
      final name = value['name'];
      final calories = value['calories'];
      final protein = value['protein'];

      if (dateValue is int && name is String && calories is int && protein is double) {
        return FoodLog(
          id: key,
          date: DateTime.fromMillisecondsSinceEpoch(dateValue),
          name: name,
          calories: calories,
          protein: protein,
        );
      }
    }
    return null;
  }

  List<FoodLog> _allLogs(Box box) {
    return box.toMap().entries
        .map((entry) => _foodLogFromHive(entry.key as int, entry.value))
        .whereType<FoodLog>()
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int _calculateTotalCalories(List<FoodLog> logs) {
    return logs.fold(0, (sum, log) => sum + log.calories);
  }

  double _calculateTotalProtein(List<FoodLog> logs) {
    return logs.fold(0.0, (sum, log) => sum + log.protein);
  }

  Future<void> _deleteLog(int id) async {
    await _box.delete(id);
  }

  Future<void> _addFoodLog(FoodLog log) async {
    await _box.add({
      'date': log.date.millisecondsSinceEpoch,
      'name': log.name,
      'calories': log.calories,
      'protein': log.protein,
    });
  }

  void _showAddFoodDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final caloriesController = TextEditingController();
        final proteinController = TextEditingController();

        return AlertDialog(
          title: const Text('Add Food'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Food name'),
              ),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calories'),
              ),
              TextField(
                controller: proteinController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Protein'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final calories = int.tryParse(caloriesController.text.trim());
                final protein = double.tryParse(proteinController.text.trim());

                if (name.isEmpty || calories == null || protein == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all values correctly.')),
                  );
                  return;
                }

                final log = FoodLog(
                  date: DateTime.now(),
                  name: name,
                  calories: calories,
                  protein: protein,
                );

                await _addFoodLog(log);
                if (!mounted) return;
                Navigator.of(this.context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Log Dashboard')),
      body: ValueListenableBuilder<Box>(
        valueListenable: _box.listenable(),
        builder: (context, box, _) {
          final logs = _allLogs(box);
          final today = DateTime.now();
          final todayLogs = logs.where((log) {
            return log.date.year == today.year &&
                log.date.month == today.month &&
                log.date.day == today.day;
          }).toList();

          final totalCalories = _calculateTotalCalories(todayLogs);
          final totalProtein = _calculateTotalProtein(todayLogs);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Today Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Calories: $totalCalories kcal'),
                            Text('Protein: ${totalProtein.toStringAsFixed(1)} g'),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? const Center(child: Text('No food logs yet.'))
                    : ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return ListTile(
                            title: Text(log.name),
                            subtitle: Text('${log.calories} kcal · ${log.protein.toStringAsFixed(1)} g · ${log.date.toLocal()}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: log.id == null
                                  ? null
                                  : () async {
                                      await _deleteLog(log.id!);
                                    },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFoodDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
