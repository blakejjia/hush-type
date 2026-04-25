import 'package:flutter/material.dart';
import '../../main.dart';

class ThemeColorPage extends StatelessWidget {
  const ThemeColorPage({super.key});

  final List<Color> _colors = const [
    Color(0xFF6366F1), // Indigo
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFFD946EF), // Fuchsia
    Color(0xFF8B5CF6), // Violet
    Color(0xFF64748B), // Slate
    Color(0xFFF43F5E), // Rose
    Color(0xFF84CC16), // Lime
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Color', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: _colors.length,
        itemBuilder: (context, index) {
          final color = _colors[index];
          final isSelected = themeManager.primaryColor.value == color.value;

          return GestureDetector(
            onTap: () {
              themeManager.setPrimaryColor(color);
              Navigator.pop(context);
            },
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 32)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
