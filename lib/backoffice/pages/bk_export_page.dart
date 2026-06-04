import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/bk_file_download.dart';

class BkExportPage extends StatelessWidget {
  const BkExportPage({super.key});

  Future<String?> _selectFormat(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5F5F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Seleziona formato"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text("PDF"),
                onTap: () => Navigator.pop(context, "PDF"),
              ),

              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text("Excel"),
                onTap: () => Navigator.pop(context, "EXCEL"),
              ),

              ListTile(
                leading: const Icon(Icons.description),
                title: const Text("Word"),
                onTap: () => Navigator.pop(context, "WORD"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _downloadExcel(String fileName, Excel excel) {
    final bytes = excel.encode();
    bkDownloadBytes(fileName, bytes!);
  }

  void _handleExport(BuildContext context, String type) async {

    final format = await _selectFormat(context);
    if (format == null) return;

    final firestore = FirebaseFirestore.instance;

    List<Map<String, dynamic>> data = [];

    if (type == "utenti") {
      final snapshot = await firestore.collection('users').get();
      data = snapshot.docs.map((e) => e.data()).toList();
    } else if (type == "corsi") {
      final snapshot = await firestore.collection('courses').get();
      data = snapshot.docs.map((e) => e.data()).toList();
    } else if (type == "aziende") {
      final snapshot = await firestore.collection('companies').get();
      data = snapshot.docs.map((e) => e.data()).toList();
    } else if (type == "offerte") {
      final snapshot = await firestore.collection('job_offers').get();
      data = snapshot.docs.map((e) => e.data()).toList();
    }

    // ---------------- EXCEL ----------------
    if (format == "EXCEL") {

      final excel = Excel.createExcel();
      final sheet = excel['Export'];

      if (data.isNotEmpty) {
        final keys = data.first.keys.where((k) {
          final v = data.first[k];
          return v is String || v is num || v is bool || v is Timestamp;
        }).toList();

        sheet.appendRow(keys.map((e) => TextCellValue(e)).toList());

        for (var row in data) {
          sheet.appendRow(
            keys.map((k) => TextCellValue(_cleanValue(row[k]))).toList(),
          );
        }
      }

      _downloadExcel("$type.xlsx", excel);
    }

    // ---------------- PDF ----------------
    else if (format == "PDF") {

      final pdf = pw.Document();

      if (data.isNotEmpty) {
        final keys = data.first.keys.where((k) {
          final v = data.first[k];
          return v is String || v is num || v is bool || v is Timestamp;
        }).toList();

        pdf.addPage(
          pw.Page(
            build: (context) {
              return pw.TableHelper.fromTextArray(
                headers: keys,
                data: data.map((row) {
                  return keys.map((k) => _cleanValue(row[k])).toList();
                }).toList(),
              );
            },
          ),
        );
      }

      final bytes = await pdf.save();
      bkDownloadBytes("$type.pdf", bytes);
    }

    // ---------------- WORD ----------------
    else if (format == "WORD") {

      if (data.isEmpty) {
        bkDownloadBytes("$type.doc", utf8.encode("Nessun dato"));
      } else {

        final keys = data.first.keys.where((k) {
          final v = data.first[k];
          return v is String || v is num || v is bool || v is Timestamp;
        }).toList();

        final buffer = StringBuffer(keys.join('\t'));
        buffer.writeln();

        for (var row in data) {
          buffer.writeln(keys.map((k) => _cleanValue(row[k])).join('\t'));
        }

        bkDownloadBytes("$type.doc", utf8.encode(buffer.toString()));
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export $type completato ($format)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView(
        children: [
          const Text(
            'Qui puoi scaricare i dati dal sistema per backup o analisi. '
                'Seleziona il tipo di esportazione e il formato desiderato.',
            style: TextStyle(fontSize: 16),
          ),

          const SizedBox(height: 32),

          _exportButton(
            context,
            icon: Icons.people_alt_outlined,
            label: 'Esporta utenti',
            onTap: () => _handleExport(context, "utenti"),
          ),

          _exportButton(
            context,
            icon: Icons.menu_book_outlined,
            label: 'Esporta corsi',
            onTap: () => _handleExport(context, "corsi"),
          ),

          _exportButton(
            context,
            icon: Icons.apartment_outlined,
            label: 'Esporta aziende',
            onTap: () => _handleExport(context, "aziende"),
          ),

          _exportButton(
            context,
            icon: Icons.work_outline,
            label: 'Esporta offerte di lavoro',
            onTap: () => _handleExport(context, "offerte"),
          ),

          const SizedBox(height: 50),
          const Divider(),

          const Text(
            'Nota: le esportazioni verranno generate in formato PDF, Excel o Word '
                'e scaricate localmente.',
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _exportButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    const accent = Color(0xFF1565C0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: Colors.white,
            elevation: 1,
            shadowColor: const Color(0x1A000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: accent.withValues(alpha: 0.22)),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212121),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.file_download_outlined,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 🔹 CLEAN DATA
String _cleanValue(dynamic value) {
  if (value == null) return '';

  if (value is Timestamp) {
    return value.toDate().toString();
  }

  if (value is Map || value is List) {
    return '';
  }

  return value.toString();
}