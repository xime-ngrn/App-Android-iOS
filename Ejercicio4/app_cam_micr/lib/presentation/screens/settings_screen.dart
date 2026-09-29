import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/thumbnail_service.dart';
import '../../domain/usecases/media_usecases.dart';
import '../providers/settings_provider.dart';
import '../widgets/dialogs.dart';
import '../widgets/transfer_actions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  int? _usageBytes;
  Map<String, PermissionStatus> _permissions = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los Ajustes del sistema se actualiza el estado de permisos.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final useCases = context.read<MediaUseCases>();
    final permissions = context.read<PermissionService>();
    final results = await Future.wait<Object>([
      useCases.storage.usage(),
      permissions.summary(),
    ]);
    if (!mounted) return;
    setState(() {
      _usageBytes = results[0] as int;
      _permissions = results[1] as Map<String, PermissionStatus>;
    });
  }

  Future<void> _run(String doneMessage, Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
      if (mounted) showSnack(context, doneMessage);
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  String _statusLabel(PermissionStatus s) {
    if (s.isGranted) return 'Concedido';
    if (s.isLimited) return 'Limitado';
    if (s.isPermanentlyDenied) return 'Denegado permanentemente';
    if (s.isRestricted) return 'Restringido';
    return 'No concedido';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Section('Tema'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final palette in AppPalette.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _PaletteCard(
                        palette: palette,
                        selected: settings.palette == palette,
                        onTap: () => settings.setPalette(palette),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Sistema')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Claro')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Oscuro')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          const SizedBox(height: 8),
          _Section('Captura'),
          SwitchListTile(
            secondary: const Icon(Icons.place_outlined),
            title: const Text('Guardar ubicación'),
            subtitle: const Text('Agrega latitud y longitud a los metadatos de cada captura'),
            value: settings.saveLocation,
            onChanged: settings.setSaveLocation,
          ),
          _Section('Almacenamiento'),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: const Text('Espacio usado'),
            subtitle: Text(_usageBytes == null ? 'Calculando…' : formatBytes(_usageBytes!)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_size_select_large_outlined),
            title: const Text('Regenerar miniaturas'),
            subtitle: const Text('Útil si alguna miniatura se ve dañada'),
            enabled: !_busy,
            onTap: () => _run('Miniaturas regeneradas', () async {
              final thumbs = context.read<ThumbnailService>();
              await context.read<MediaUseCases>().storage.rebuildThumbnails();
              thumbs.clearMemory();
              PaintingBinding.instance.imageCache.clear();
            }),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Liberar caché en memoria'),
            enabled: !_busy,
            onTap: () {
              context.read<ThumbnailService>().clearMemory();
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              showSnack(context, 'Caché liberada');
            },
          ),
          _Section('Exportar e importar'),
          Builder(
            builder: (btnContext) => ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Exportar todo (.zip)'),
              subtitle: const Text('Incluye archivos y metadatos (manifest.json)'),
              enabled: !_busy,
              onTap: () async {
                final items = await context.read<MediaUseCases>().loadGallery();
                if (btnContext.mounted) await exportItems(btnContext, items);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Importar desde .zip'),
            enabled: !_busy,
            onTap: () async {
              await importFromZip(context);
              await _refresh();
            },
          ),
          _Section('Permisos'),
          for (final entry in _permissions.entries)
            ListTile(
              leading: Icon(
                entry.value.isGranted ? Icons.check_circle_outline : Icons.error_outline,
                color: entry.value.isGranted ? scheme.primary : scheme.error,
              ),
              title: Text(entry.key),
              subtitle: Text(_statusLabel(entry.value)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => context.read<PermissionService>().openSettings(),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Abrir ajustes del sistema'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text('CamMic ESCOM · Aplicaciones Móviles · ESCOM-IPN',
                style: text.bodySmall, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({required this.palette, required this.selected, required this.onTap});
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: palette.seed,
                child: selected ? const Icon(Icons.check, color: Colors.white) : null,
              ),
              const SizedBox(height: 8),
              Text(palette.label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
