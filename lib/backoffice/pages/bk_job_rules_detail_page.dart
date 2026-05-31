import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:backoffice/backoffice/widgets/bk_impaginazione_secondaria.dart';

class BkJobRulesDetailPage extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final String version;
  final bool readOnly;
  final Future<void> Function() onSave;

  const BkJobRulesDetailPage({
    super.key,
    required this.title,
    required this.controller,
    required this.version,
    required this.readOnly,
    required this.onSave,
  });

  @override
  State<BkJobRulesDetailPage> createState() => _BkJobRulesDetailPageState();
}

class _BkJobRulesDetailPageState extends State<BkJobRulesDetailPage> {

  String _initialText = '';
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();

    _initialText = widget.controller.text;

    widget.controller.addListener(() {
      final changed = widget.controller.text != _initialText;

      if (changed != _hasChanges) {
        setState(() {
          _hasChanges = changed;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ImpaginazioneSecondariaBk(
      pageTitle: widget.title,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Versione regolamento: ${widget.version}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Markdown(
                data: widget.controller.text,
              ),
            ),

            if (!widget.readOnly) ...[

              const SizedBox(height: 16),

              Expanded(
                child: TextField(
                  controller: widget.controller,
                  expands: true,
                  maxLines: null,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _hasChanges
                    ? () async {
                  await widget.onSave();
                  _initialText = widget.controller.text;

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
                    : null,
                child: const Text("Salva"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}