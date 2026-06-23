import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../models/assignment.dart';
import '../state/field_provider.dart';

class ReadingEntryScreen extends StatefulWidget {
  const ReadingEntryScreen({super.key, required this.assignment});
  final Assignment assignment;

  @override
  State<ReadingEntryScreen> createState() => _ReadingEntryScreenState();
}

class _ReadingEntryScreenState extends State<ReadingEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reading = TextEditingController();
  bool _estimate = false;
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing =
        context.read<FieldProvider>().entryFor(widget.assignment.connectionId);
    if (existing != null) {
      _reading.text = existing.currentReading ?? '';
      _estimate = existing.currentReading == null;
      _photoPath = existing.photoPath;
    }
  }

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  String? _validateReading(String? v) {
    if (_estimate) return null;
    if (v == null || v.trim().isEmpty) {
      return 'Wajib diisi (atau pilih estimasi)';
    }
    final current = Decimal.tryParse(v.trim());
    if (current == null) return 'Angka tidak valid';
    if (current < Decimal.zero) return 'Tidak boleh negatif';
    // Peringatan lunak; server tetap otoritatif (§8).
    final last = Decimal.tryParse(widget.assignment.lastReading);
    if (last != null && current < last) {
      return 'Lebih kecil dari bacaan terakhir (${widget.assignment.lastReading})';
    }
    return null;
  }

  String? get _consumptionPreview {
    if (_estimate || _reading.text.trim().isEmpty) return null;
    final current = Decimal.tryParse(_reading.text.trim());
    final last = Decimal.tryParse(widget.assignment.lastReading);
    if (current == null || last == null || current < last) return null;
    return (current - last).toString();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (x == null) return;

    final file = File(x.path);
    // Pra-validasi (§4.4).
    if (file.lengthSync() > ApiConfig.photoMaxBytes) {
      _snack('Foto melebihi 5 MB. Ambil ulang.');
      return;
    }
    setState(() => _photoPath = x.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final field = context.read<FieldProvider>();
    await field.saveReading(
      assignment: widget.assignment,
      currentReading: _estimate ? null : _reading.text.trim(),
      photoPath: _photoPath,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _snack('Tersimpan lokal. Tekan "Sinkronkan" saat ada sinyal.');
    Navigator.of(context).pop();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return Scaffold(
      appBar: AppBar(title: Text(a.meterNo)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.customerName,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(a.address),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bacaan terakhir'),
                        Text(a.lastReading,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Estimasi (meter tidak terbaca)'),
              subtitle: const Text('Server akan menghitung angka estimasi'),
              value: _estimate,
              onChanged: (v) => setState(() => _estimate = v),
            ),
            if (!_estimate) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _reading,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Angka meter sekarang',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
                validator: _validateReading,
                onChanged: (_) => setState(() {}),
              ),
              if (_consumptionPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Perkiraan konsumsi: $_consumptionPreview m³',
                      style: TextStyle(color: Colors.blue.shade700)),
                ),
            ],
            const SizedBox(height: 20),
            Text('Foto meter', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_photoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(_photoPath!),
                    height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Simpan (offline)'),
            ),
          ],
        ),
      ),
    );
  }
}
