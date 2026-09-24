import 'package:flutter/material.dart';

import '../board/board_controller.dart';
import '../board/models.dart';
import 'card_tile.dart';
import 'dialogs.dart';
import 'inline_composer.dart';

const listColumnWidth = 280.0;

/// A single board column: header, its queue of cards and a card composer.
class ListColumn extends StatelessWidget {
  const ListColumn({super.key, required this.list, required this.controller});

  final TaskList list;
  final BoardController controller;

  Future<void> _openCard(BuildContext context, TaskCard card) async {
    final result = await showCardEditor(
      context,
      card: card,
      listTitle: list.title,
    );
    switch (result) {
      case CardEdited(:final title, :final description):
        controller.updateCard(card.id, title: title, description: description);
      case CardDeleted():
        controller.removeCard(card.id);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: listColumnWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHeader(list: list, controller: controller),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: list.cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final card = list.cards[index];
                return CardTile(
                  key: ValueKey(card.id),
                  card: card,
                  onTap: () => _openCard(context, card),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          InlineComposer(
            buttonLabel: 'Adicionar tarefa',
            hintText: 'Título da tarefa…',
            submitLabel: 'Adicionar',
            multiline: true,
            onSubmit: (title) => controller.addCard(list.id, title),
          ),
        ],
      ),
    );
  }
}

enum _ListAction { rename, delete }

class ListHeader extends StatelessWidget {
  const ListHeader({super.key, required this.list, required this.controller});

  final TaskList list;
  final BoardController controller;

  Future<void> _rename(BuildContext context) async {
    final title = await promptText(
      context,
      title: 'Renomear lista',
      label: 'Nome da lista',
      initialValue: list.title,
    );
    if (title != null) controller.renameList(list.id, title);
  }

  Future<void> _delete(BuildContext context) async {
    final count = list.cards.length;
    final confirmed =
        count == 0 ||
        await confirm(
          context,
          title: 'Excluir lista?',
          message:
              'A lista "${list.title}" e ${count == 1 ? 'sua tarefa' : 'suas $count tarefas'} '
              'serão removidas permanentemente.',
          action: 'Excluir',
        );
    if (confirmed) controller.removeList(list.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onDoubleTap: () => _rename(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
              child: Text(
                list.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        _CountBadge(count: list.cards.length),
        PopupMenuButton<_ListAction>(
          tooltip: 'Ações da lista',
          icon: const Icon(Icons.more_horiz, size: 20),
          onSelected: (action) => switch (action) {
            _ListAction.rename => _rename(context),
            _ListAction.delete => _delete(context),
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _ListAction.rename,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Renomear'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _ListAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Excluir lista'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
      ),
    );
  }
}
