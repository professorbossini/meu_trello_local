import 'package:flutter/material.dart';

import '../board/models.dart';

/// Result of [showCardEditor].
sealed class CardEditorResult {}

class CardEdited extends CardEditorResult {
  CardEdited(this.title, this.description);

  final String title;
  final String description;
}

class CardDeleted extends CardEditorResult {}

/// Opens the card details dialog. Returns `null` when dismissed.
Future<CardEditorResult?> showCardEditor(
  BuildContext context, {
  required TaskCard card,
  required String listTitle,
}) {
  return showDialog<CardEditorResult>(
    context: context,
    builder: (_) => _CardEditorDialog(card: card, listTitle: listTitle),
  );
}

class _CardEditorDialog extends StatefulWidget {
  const _CardEditorDialog({required this.card, required this.listTitle});

  final TaskCard card;
  final String listTitle;

  @override
  State<_CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends State<_CardEditorDialog> {
  late final _title = TextEditingController(text: widget.card.title);
  late final _description = TextEditingController(
    text: widget.card.description,
  );

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, CardEdited(title, _description.text));
  }

  Future<void> _delete() async {
    final confirmed = await confirm(
      context,
      title: 'Excluir tarefa?',
      message: '"${widget.card.title}" será removida permanentemente.',
      action: 'Excluir',
    );
    if (confirmed && mounted) Navigator.pop(context, CardDeleted());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = MaterialLocalizations.of(
      context,
    ).formatMediumDate(widget.card.createdAt);

    return AlertDialog(
      title: Text(
        'Na lista ${widget.listTitle}',
        style: theme.textTheme.labelLarge,
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              style: theme.textTheme.titleLarge,
              decoration: const InputDecoration(labelText: 'Título'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _description,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Criada em $created',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Excluir'),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
        ),
        const SizedBox(width: 24),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}

/// Asks the user for a single line of text. Returns `null` when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String action = 'Salvar',
}) {
  final controller = TextEditingController(text: initialValue);
  void submit(BuildContext context) {
    final value = controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (_) => submit(context),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: () => submit(context), child: Text(action)),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Shows a destructive confirmation dialog.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
