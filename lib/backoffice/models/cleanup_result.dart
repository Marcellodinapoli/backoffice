/// Esito pulizia database da Impostazioni.
class CleanupResult {
  final int pendingLoginsDeleted;
  final int obsoleteDocsDeleted;
  final List<String> errors;

  const CleanupResult({
    this.pendingLoginsDeleted = 0,
    this.obsoleteDocsDeleted = 0,
    this.errors = const [],
  });

  int get total => pendingLoginsDeleted + obsoleteDocsDeleted;

  bool get hasErrors => errors.isNotEmpty;

  String summaryMessage() {
    if (total == 0 && !hasErrors) {
      return 'Nessun elemento da rimuovere.';
    }

    final parts = <String>[
      if (pendingLoginsDeleted > 0)
        '$pendingLoginsDeleted pendingLogins scaduti',
      if (obsoleteDocsDeleted > 0) '$obsoleteDocsDeleted documenti test/debug',
    ];

    var message = parts.isEmpty
        ? 'Pulizia completata.'
        : 'Pulizia completata: ${parts.join(', ')}.';

    if (hasErrors) {
      message += ' Alcune operazioni non sono riuscite (${errors.length}).';
    }

    return message;
  }
}
