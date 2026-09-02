import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'detail.dart';
import 'home.dart';
import 'reminders.dart';
import 'store.dart';
import 'theme.dart';

/// A page of its own rather than a sheet: settings is a place you go, not a
/// thing you glance at, and half of it — restoring a backup, the notification
/// permission — is work you want the whole screen for.
void openSettings(BuildContext context, HabitStore store) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SettingsScreen(store: store),
  ));
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => _SettingsBody(store: store),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.store});

  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final archived = store.archived;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text('Appearance', style: text.labelSmall),
            const SizedBox(height: 8),
            Segmented<ThemeMode>(
              options: const {
                ThemeMode.system: 'System',
                ThemeMode.light: 'Light',
                ThemeMode.dark: 'Dark',
              },
              value: store.themeMode,
              onChanged: store.setThemeMode,
            ),
            const SizedBox(height: 24),
            Text('Reminders', style: text.labelSmall),
            const SizedBox(height: 8),
            SoftCard(
              padding: EdgeInsets.zero,
              child: _Row(
                icon: Icons.notifications_none,
                label: 'Allow notifications',
                subtitle: 'Needed before a habit reminder can arrive',
                onTap: () => _askForNotifications(context),
              ),
            ),
            const SizedBox(height: 24),
            Text('Your data', style: text.labelSmall),
            const SizedBox(height: 8),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Row(
                    icon: Icons.ios_share,
                    label: 'Export a backup',
                    subtitle: '${store.habits.length} habits as a JSON file',
                    onTap: () => _export(context, store),
                  ),
                  const Divider(indent: 52),
                  _Row(
                    icon: Icons.download_outlined,
                    label: 'Restore from a backup',
                    subtitle: 'Replaces everything on this device',
                    onTap: () => _import(context, store),
                  ),
                  if (archived.isNotEmpty) ...[
                    const Divider(indent: 52),
                    _Row(
                      icon: Icons.inventory_2_outlined,
                      label: 'Archived habits',
                      subtitle: '${archived.length} hidden',
                      onTap: () => _showArchived(context, store),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The reminder permission, asked for from the one place someone goes looking
/// when a nudge never arrived. Android says no without a prompt once it has
/// been permanently denied, so the failure has to name the phone's own
/// settings rather than repeat itself.
Future<void> _askForNotifications(BuildContext context) async {
  final allowed = await reminders.requestPermission();
  if (!context.mounted) return;
  showToast(
    context,
    SnackBar(
      content: Text(allowed
          ? 'Notifications are on. Set a time on any habit.'
          : 'Blocked. Turn Wick\'s notifications on in your phone\'s settings.'),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 1),
                  Text(subtitle, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: theme.colorScheme.surfaceContainerHighest),
          ],
        ),
      ),
    );
  }
}

Future<void> _export(BuildContext context, HabitStore store) async {
  try {
    final dir = await Directory.systemTemp.createTemp('habits_export');
    final file = File('${dir.path}/habits-${dayKey(today())}.json');
    await file.writeAsString(store.exportJson());
    if (!context.mounted) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'Habit backup',
    ));
  } catch (e) {
    if (context.mounted) toast(context, 'Could not export: $e');
  }
}

Future<void> _import(BuildContext context, HabitStore store) async {
  final picked = await FilePicker.pickFile(
    dialogTitle: 'Choose a habit backup',
  );
  if (picked == null) return;

  final String raw;
  try {
    raw = utf8.decode(await picked.readAsBytes());
  } catch (e) {
    if (context.mounted) toast(context, 'Could not read that file');
    return;
  }
  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Replace all data?'),
      content: Text(
        'This wipes the ${store.habits.length} habits on this device and '
        'restores the backup instead. It can\'t be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Replace', style: TextStyle(color: flameOf(context))),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    // Throws before touching anything if the file is malformed, so a bad
    // import can't destroy the existing data.
    store.importJson(raw);
    Navigator.pop(context);
    toast(context, 'Restored ${store.habits.length} habits');
  } catch (e) {
    toast(context, 'That file isn\'t a valid habit backup');
  }
}

void _showArchived(BuildContext context, HabitStore store) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final archived = store.archived;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text('Archived',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                const SizedBox(height: 20),
                if (archived.isEmpty)
                  Center(
                    child: Text('Nothing archived',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                for (final h in archived)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                      child: Row(
                        children: [
                          HabitAccent(
                            color: habitColorAt(h.color),
                            child: HabitIcon(habit: h, size: 30),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              h.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () => store.setArchived(h, false),
                            child: Text('Restore',
                                style: TextStyle(color: flameOf(context))),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
