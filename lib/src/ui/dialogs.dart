import 'package:flutter/material.dart';

import '../board/models.dart';
import 'theme.dart';

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
  return showAppDialog<CardEditorResult>(
    context,
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

  // Deleting can be undone from the snack bar, so no confirmation.
  void _delete() => Navigator.pop(context, CardDeleted());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = MaterialLocalizations.of(
      context,
    ).formatMediumDate(widget.card.createdAt);

    return AlertDialog(
      scrollable: true,
      title: Text(
        'Na lista ${widget.listTitle}',
        style: theme.textTheme.labelLarge,
      ),
      content: _DialogWidth(
        maxWidth: 520,
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
          icon: const Icon(Icons.delete_outline_rounded),
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

  return showAppDialog<String>(
    context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: _DialogWidth(
        maxWidth: 360,
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

/// Shows a dialog that fades and scales in with Material 3's emphasized
/// easing, and fades out quickly.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: Motion.long,
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.emphasized,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Makes dialog content as wide as [maxWidth], or narrower when the window
/// is too small for it.
class _DialogWidth extends StatelessWidget {
  const _DialogWidth({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: SizedBox(width: double.maxFinite, child: child),
  );
}
