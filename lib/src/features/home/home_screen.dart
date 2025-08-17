
import 'package:flutter/material.dart';
import 'package:tree_measure_app/src/features/identification/identification_screen.dart';
import 'package:tree_measure_app/src/features/measurement/measurement_screen.dart';
import 'package:tree_measure_app/src/features/history/history_screen.dart';
import 'package:tree_measure_app/src/features/location/location_screen.dart';
import 'package:tree_measure_app/src/features/settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tree Measurement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildFeatureCard(
              context,
              icon: Icons.straighten, // Icon for measurement
              label: 'Đo cây',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MeasurementScreen()),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.history, // Icon for history
              label: 'Lịch sử đo',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.eco, // Icon for species identification
              label: 'Nhận dạng cây',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const IdentificationScreen()),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.map,
              label: 'Bản đồ',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LocationScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
