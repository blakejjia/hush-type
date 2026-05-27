import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/app_settings_service.dart';

class PresetColor {
  final String name;
  final Color color;
  final String hex;

  const PresetColor({
    required this.name,
    required this.color,
    required this.hex,
  });
}

class FloatingMicCustomizePage extends StatefulWidget {
  const FloatingMicCustomizePage({super.key});

  @override
  State<FloatingMicCustomizePage> createState() => _FloatingMicCustomizePageState();
}

class _FloatingMicCustomizePageState extends State<FloatingMicCustomizePage> {
  static const _platform = MethodChannel('com.jia_yx.hashtype/ime');
  final AppSettingsService _settingsService = AppSettingsService();

  String _selectedColor = 'theme';
  String _selectedSize = 'medium';
  String _selectedIcon = 'mic';
  bool _isMockRecording = false;
  Map<String, String>? _systemThemeColors;

  final List<PresetColor> _presets = const [
    PresetColor(name: 'Indigo', color: Color(0xFF6366F1), hex: '#FF6366F1'),
    PresetColor(name: 'Sky Blue', color: Color(0xFF0EA5E9), hex: '#FF0EA5E9'),
    PresetColor(name: 'Emerald', color: Color(0xFF10B981), hex: '#FF10B981'),
    PresetColor(name: 'Amber', color: Color(0xFFF59E0B), hex: '#FFF59E0B'),
    PresetColor(name: 'Red', color: Color(0xFFEF4444), hex: '#FFEF4444'),
    PresetColor(name: 'Fuchsia', color: Color(0xFFD946EF), hex: '#FFD946EF'),
    PresetColor(name: 'Violet', color: Color(0xFF8B5CF6), hex: '#FF8B5CF6'),
    PresetColor(name: 'Slate', color: Color(0xFF64748B), hex: '#FF64748B'),
    PresetColor(name: 'Rose', color: Color(0xFFF43F5E), hex: '#FFF43F5E'),
    PresetColor(name: 'Lime', color: Color(0xFF84CC16), hex: '#FF84CC16'),
  ];

  final Map<String, IconData> _icons = const {
    'mic': Icons.mic_rounded,
    'heart': Icons.favorite_rounded,
    'star': Icons.star_rounded,
    'chat': Icons.chat_bubble_rounded,
    'music': Icons.music_note_rounded,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final color = await _settingsService.getFloatingMicColor();
    final size = await _settingsService.getFloatingMicSize();
    final icon = await _settingsService.getFloatingMicIcon();

    Map<String, String>? systemThemeColors;
    try {
      final Map<dynamic, dynamic>? result =
          await _platform.invokeMethod('getSystemThemeColors');
      if (result != null) {
        systemThemeColors = result.cast<String, String>();
      }
    } catch (e) {
      debugPrint('Failed to get system theme colors: $e');
    }

    if (mounted) {
      setState(() {
        _selectedColor = color;
        _selectedSize = size;
        _selectedIcon = icon;
        _systemThemeColors = systemThemeColors;
      });
    }
  }

  void _updateColor(String value) {
    setState(() {
      _selectedColor = value;
    });
  }

  void _updateSize(String value) {
    setState(() {
      _selectedSize = value;
    });
  }

  void _updateIcon(String value) {
    setState(() {
      _selectedIcon = value;
    });
  }

  Future<void> _saveSettings() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await _settingsService.setFloatingMicColor(_selectedColor);
      await _settingsService.setFloatingMicSize(_selectedSize);
      await _settingsService.setFloatingMicIcon(_selectedIcon);

      String iconColorHex = '#FFFFFF';
      if (_selectedColor != 'theme') {
        final color = _hexToColor(_selectedColor);
        if (color.computeLuminance() > 0.5) {
          iconColorHex = '#000000';
        }
      }
      await _settingsService.setFloatingMicIconColor(iconColorHex);

      await _platform.invokeMethod('updateFloatingMicSettings');

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text('Customization saved & applied!'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Color _hexToColor(String hex) {
    if (hex == 'theme') return Colors.transparent;
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Resolve size parameters
    double cardSize = 56.0;
    double iconSize = 24.0;
    switch (_selectedSize) {
      case 'small':
        cardSize = 44.0;
        iconSize = 20.0;
        break;
      case 'large':
        cardSize = 68.0;
        iconSize = 28.0;
        break;
    }

    // Resolve colors for the preview
    Color previewBg;
    Color previewIconColor;

    if (_isMockRecording) {
      if (_selectedColor == 'theme' && _systemThemeColors != null) {
        previewBg = _hexToColor(_systemThemeColors!['colorErrorContainer']!);
        previewIconColor = _hexToColor(_systemThemeColors!['colorOnErrorContainer']!);
      } else {
        previewBg = theme.colorScheme.errorContainer;
        previewIconColor = theme.colorScheme.onErrorContainer;
      }
    } else if (_selectedColor == 'theme') {
      if (_systemThemeColors != null) {
        previewBg = _hexToColor(_systemThemeColors!['colorSecondaryContainer']!);
        previewIconColor = _hexToColor(_systemThemeColors!['colorOnSecondaryContainer']!);
      } else {
        previewBg = theme.colorScheme.secondaryContainer;
        previewIconColor = theme.colorScheme.onSecondaryContainer;
      }
    } else {
      previewBg = _hexToColor(_selectedColor);
      previewIconColor = Colors.white;
    }

    final IconData previewIcon = _icons[_selectedIcon] ?? Icons.mic_rounded;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customize Floating Mic',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Save',
            onPressed: _saveSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // Live Preview Section
          Center(
            child: Column(
              children: [
                Text(
                  'LIVE PREVIEW',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                    ),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Grid lines to make it feel like an overlay preview
                      Positioned.fill(
                        child: CustomPaint(
                          painter: GridPainter(isDark: isDark),
                        ),
                      ),
                      // The interactive preview button itself
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isMockRecording = !_isMockRecording;
                          });
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _isMockRecording
                                    ? 'Mock State: Recording (pulsing/error is colored red)'
                                    : 'Mock State: Idle (custom style active)',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: cardSize,
                          height: cardSize,
                          decoration: BoxDecoration(
                            color: previewBg,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: previewBg == Colors.transparent
                                    ? Colors.black12
                                    : previewBg.withValues(alpha: 0.4),
                                blurRadius: _isMockRecording ? 16 : 8,
                                spreadRadius: _isMockRecording ? 4 : 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            previewIcon,
                            size: iconSize,
                            color: previewIconColor,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        child: Text(
                          _isMockRecording
                              ? 'Tap to stop recording demo'
                              : 'Tap to preview recording state',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Size Selection Section
          _buildSectionTitle(theme, 'Button Size'),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSizeCard(context, 'small', 'Small', '44 dp'),
              const SizedBox(width: 12),
              _buildSizeCard(context, 'medium', 'Medium', '56 dp'),
              const SizedBox(width: 12),
              _buildSizeCard(context, 'large', 'Large', '68 dp'),
            ],
          ),
          const SizedBox(height: 32),

          // Icon Selection Section
          _buildSectionTitle(theme, 'Button Icon'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _icons.entries.map((entry) {
              final isSelected = _selectedIcon == entry.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _updateIcon(entry.key),
                  child: Card(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Icon(
                        entry.value,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Color Palette Section
          _buildSectionTitle(theme, 'Button Color (Idle State)'),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic / Theme toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use System Theme Colors'),
                    subtitle: const Text('Adapts to keyboard accent & mode'),
                    trailing: Switch(
                      value: _selectedColor == 'theme',
                      onChanged: (v) {
                        if (v) {
                          _updateColor('theme');
                        } else {
                          _updateColor(_presets.first.hex);
                        }
                      },
                    ),
                  ),
                  if (_selectedColor != 'theme') ...[
                    const Divider(height: 24),
                    const Text(
                      'Vibrant Presets',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 64,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _presets.length,
                        itemBuilder: (context, index) {
                          final preset = _presets[index];
                          final isSelected = _selectedColor == preset.hex;

                          return GestureDetector(
                            onTap: () => _updateColor(preset.hex),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: preset.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: preset.color.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: preset.color.computeLuminance() > 0.5
                                          ? Colors.black87
                                          : Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_rounded),
            label: const Text(
              'Save & Apply Style',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSizeCard(
    BuildContext context,
    String sizeKey,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);
    final isSelected = _selectedSize == sizeKey;

    return Expanded(
      child: GestureDetector(
        onTap: () => _updateSize(sizeKey),
        child: Card(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                        : theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final bool isDark;
  GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white10 : Colors.black12
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
