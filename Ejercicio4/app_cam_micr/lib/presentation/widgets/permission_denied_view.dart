import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/permissions/permission_service.dart';

class PermissionDeniedView extends StatelessWidget {
  const PermissionDeniedView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Volver a intentar'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.read<PermissionService>().openSettings(),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Abrir ajustes del sistema'),
            ),
          ],
        ),
      ),
    );
  }
}
