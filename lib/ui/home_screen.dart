import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/assignment.dart';
import '../models/period.dart';
import '../models/reading_entry.dart';
import '../state/auth_provider.dart';
import '../state/field_provider.dart';
import 'reading_entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FieldProvider>().loadPeriods();
    });
  }

  @override
  Widget build(BuildContext context) {
    final field = context.watch<FieldProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas Baca Meter'),
        actions: [
          if (field.unsyncedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('${field.unsyncedCount} antri'),
                backgroundColor: Colors.orange.shade100,
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') await auth.signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(auth.user?.name ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Keluar')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!field.online)
            Container(
              width: double.infinity,
              color: Colors.grey.shade800,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Mode offline — bacaan disimpan lokal',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          _PeriodBar(field: field),
          if (field.error != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(field.error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          Expanded(child: _AssignmentList(field: field)),
        ],
      ),
      floatingActionButton: field.selectedPeriod == null
          ? null
          : FloatingActionButton.extended(
              onPressed: field.syncing ? null : () => _runSync(context, field),
              icon: field.syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              label: Text(field.syncing ? 'Sinkron…' : 'Sinkronkan'),
            ),
    );
  }

  Future<void> _runSync(BuildContext context, FieldProvider field) async {
    await field.syncNow();
    if (!context.mounted) return;
    final r = field.lastSync;
    final msg = r == null
        ? (field.error ?? 'Sinkronisasi gagal.')
        : 'Tersimpan ${r.synced} · Galat ${r.errors} · Foto ${r.photosUploaded}'
            '${r.anomalies > 0 ? ' · ⚠ ${r.anomalies} anomali' : ''}';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.field});
  final FieldProvider field;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 20),
            const SizedBox(width: 8),
            const Text('Periode:'),
            const SizedBox(width: 12),
            Expanded(
              child: field.loading && field.periods.isEmpty
                  ? const LinearProgressIndicator()
                  : DropdownButton<Period>(
                      isExpanded: true,
                      value: field.selectedPeriod,
                      hint: const Text('Pilih periode terbuka'),
                      items: field.periods
                          .map((p) => DropdownMenuItem(
                              value: p, child: Text(p.code)))
                          .toList(),
                      onChanged: (p) {
                        if (p != null) field.selectPeriod(p);
                      },
                    ),
            ),
            IconButton(
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh),
              onPressed: field.selectedPeriod == null
                  ? null
                  : () => field.selectPeriod(field.selectedPeriod!),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentList extends StatelessWidget {
  const _AssignmentList({required this.field});
  final FieldProvider field;

  @override
  Widget build(BuildContext context) {
    if (field.selectedPeriod == null) {
      return const Center(child: Text('Pilih periode untuk memuat tugas.'));
    }
    if (field.loading && field.assignments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (field.assignments.isEmpty) {
      return const Center(child: Text('Tidak ada tugas untuk periode ini.'));
    }
    return ListView.separated(
      itemCount: field.assignments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = field.assignments[i];
        return _AssignmentTile(assignment: a, entry: field.entryFor(a.connectionId));
      },
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment, this.entry});
  final Assignment assignment;
  final ReadingEntry? entry;

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final e = entry;

    Widget trailing;
    if (a.alreadyRead) {
      trailing = _badge('Sudah Dibaca', Colors.green);
    } else if (e == null) {
      trailing = const Icon(Icons.chevron_right);
    } else if (e.syncError != null) {
      trailing = _badge('Galat', Colors.red);
    } else if (!e.synced) {
      trailing = _badge('Antri', Colors.orange);
    } else if (e.isAnomaly) {
      trailing = _badge('Anomali', Colors.deepOrange);
    } else {
      trailing = _badge('Tersinkron', Colors.blue);
    }

    return ListTile(
      title: Text(a.customerName,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${a.meterNo} · ${a.address}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('Terakhir: ${a.lastReading}'
              '${e?.currentReading != null ? ' → ${e!.currentReading}' : ''}'
              '${e?.consumption != null ? '  (kons. ${e!.consumption})' : ''}'),
          if (e?.syncError != null)
            Text(e!.syncError!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          if (e != null && e.isAnomaly && e.anomalyReason != null)
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: Colors.deepOrange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(e.anomalyReason!,
                      style: const TextStyle(
                          color: Colors.deepOrange, fontSize: 12)),
                ),
              ],
            ),
        ],
      ),
      isThreeLine: true,
      trailing: trailing,
      onTap: a.alreadyRead
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReadingEntryScreen(assignment: a),
              )),
    );
  }

  Widget _badge(String text, MaterialColor color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: TextStyle(color: color.shade800, fontSize: 12)),
      );
}
