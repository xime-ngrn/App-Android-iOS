import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/audio_recorder_provider.dart';
import '../providers/gallery_provider.dart';
import 'audio_screen.dart';
import 'camera_screen.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) {
    setState(() => _index = index);
    if (index == 2) context.read<GalleryProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final recording = context.select<AudioRecorderProvider, bool>((p) => p.isActive);
    return Scaffold(
      // Sin IndexedStack a propósito: al salir de la pestaña de cámara su
      // provider se destruye y el hardware se libera.
      body: switch (_index) {
        0 => const CameraScreen(),
        1 => const AudioScreen(),
        2 => const GalleryScreen(),
        _ => const SettingsScreen(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: 'Cámara',
          ),
          NavigationDestination(
            icon: Badge(isLabelVisible: recording, child: const Icon(Icons.mic_none)),
            selectedIcon: Badge(isLabelVisible: recording, child: const Icon(Icons.mic)),
            label: 'Audio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Galería',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
