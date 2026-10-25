import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(const MejoApp());
}

class MejoApp extends StatelessWidget {
  const MejoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mejo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      home: const MejoShell(),
    );
  }
}

class MejoShell extends StatefulWidget {
  const MejoShell({super.key});

  @override
  State<MejoShell> createState() => _MejoShellState();
}

class _MejoShellState extends State<MejoShell> {
  DateTime _now = DateTime.now();
  Timer? _clock;
  bool _launcherOpen = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer timer) {
    if (mounted) {
      setState(() => _now = DateTime.now());
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  String get _timeLabel =>
      '${_pad(_now.hour)}:${_pad(_now.minute)}:${_pad(_now.second)}';

  void _toggleLauncher() {
    setState(() => _launcherOpen = !_launcherOpen);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Mejo', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 8),
                Text(
                  'Оболочка Liji',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: MejoPanel(
              timeLabel: _timeLabel,
              launcherOpen: _launcherOpen,
              onLauncherTap: _toggleLauncher,
            ),
          ),
          if (_launcherOpen)
            MejoLauncher(apps: MejoPanel.apps, onClose: _toggleLauncher),
        ],
      ),
    );
  }
}

class MejoPanel extends StatelessWidget {
  const MejoPanel({
    super.key,
    required this.timeLabel,
    required this.launcherOpen,
    required this.onLauncherTap,
  });

  final String timeLabel;
  final bool launcherOpen;
  final VoidCallback onLauncherTap;

  static const List<(IconData, String)> apps = [
    (Icons.grid_view_outlined, 'Приложения'),
    (Icons.folder_outlined, 'Файлы'),
    (Icons.terminal, 'Терминал'),
    (Icons.settings_outlined, 'Настройки'),
    (Icons.image_outlined, 'Галерея'),
    (Icons.music_note_outlined, 'Музыка'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            onPressed: onLauncherTap,
            icon: Icon(launcherOpen ? Icons.close : Icons.apps),
            tooltip: 'Лаунчер',
          ),
          const SizedBox(width: 8),
          Text(timeLabel, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class MejoLauncher extends StatelessWidget {
  const MejoLauncher({super.key, required this.apps, required this.onClose});

  final List<(IconData, String)> apps;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(32),
        ),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.4,
                children: [
                  for (final (icon, label) in apps)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {},
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: scheme.primary),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              TextButton(onPressed: onClose, child: const Text('Закрыть')),
            ],
          ),
        ),
      ),
    );
  }
}
