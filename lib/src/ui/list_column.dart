import 'package:flutter/material.dart';

import '../board/board_controller.dart';
import '../board/models.dart';
import 'card_tile.dart';
import 'dialogs.dart';
import 'drag_and_drop.dart';
import 'inline_composer.dart';

const listColumnWidth = 280.0;

/// A single board column: header, its queue of cards and a card composer.
///
/// The column is also where drag and drop comes together:
/// - dragging the header moves the whole list;
/// - dropping a list on this column places it before or after it;
/// - dropping a card on the header puts it at the top of the queue, on
///   another card before or after that card, and anywhere else in the
///   column at the bottom.
class ListColumn extends StatefulWidget {
  const ListColumn({
    super.key,
    required this.list,
    required this.index,
    required this.controller,
  });

  final TaskList list;

  /// Position of [list] on the board.
  final int index;
  final BoardController controller;

  @override
  State<ListColumn> createState() => _ListColumnState();
}

class _ListColumnState extends State<ListColumn> with BoardDragCallbacks {
  final _scroll = ScrollController();
  bool _dragging = false;
  Offset _grabOffset = Offset.zero;
  Size _size = Size.zero;
  DropSide? _listDropSide;

  TaskList get list => widget.list;
  BoardController get controller => widget.controller;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<ListDragData>(
      onWillAcceptWithDetails: (details) => details.data.listId != list.id,
      onMove: (details) {
        final box = context.findRenderObject()! as RenderBox;
        final side = DropSide.fromPosition(
          box.globalToLocal(details.offset).dx,
          box.size.width,
        );
        if (side != _listDropSide) setState(() => _listDropSide = side);
      },
      onLeave: (_) => setState(() => _listDropSide = null),
      onAcceptWithDetails: (details) {
        final slot = widget.index + (_listDropSide == DropSide.after ? 1 : 0);
        setState(() => _listDropSide = null);
        controller.moveList(details.data.listId, slot);
      },
      builder: (context, candidates, _) {
        final side = candidates.isEmpty ? null : _listDropSide;
        // The gap between columns is 12px wide; center the line inside it.
        const inset = -(12 + DropIndicator.thickness) / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              opacity: _dragging ? 0.35 : 1,
              duration: const Duration(milliseconds: 120),
              child: _buildColumn(context),
            ),
            if (side != null)
              Positioned(
                top: 0,
                bottom: 0,
                left: side == DropSide.before ? inset : null,
                right: side == DropSide.after ? inset : null,
                child: const DropIndicator(axis: Axis.vertical),
              ),
          ],
        );
      },
    );
  }

  Widget _buildColumn(BuildContext context) {
    return DragTarget<CardDragData>(
      onAcceptWithDetails: (details) =>
          controller.moveCard(details.data.cardId, list.id, list.cards.length),
      builder: (context, candidates, _) => Container(
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
            _buildHeader(context),
            Flexible(child: _buildCards(context)),
            if (candidates.isNotEmpty) ...[
              const SizedBox(height: 2),
              const DropIndicator(),
            ],
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final header = ListHeader(list: list, controller: controller);
    return DragTarget<CardDragData>(
      onAcceptWithDetails: (details) =>
          controller.moveCard(details.data.cardId, list.id, 0),
      builder: (context, candidates, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Listener(
            onPointerDown: (event) {
              final column = this.context.findRenderObject()! as RenderBox;
              _grabOffset = column.globalToLocal(event.position);
              _size = column.size;
            },
            child: BoardDraggable<ListDragData>(
              data: ListDragData(list.id),
              dragAnchorStrategy: pointerDragAnchorStrategy,
              // Built lazily so it picks up the grab point recorded above.
              feedback: Builder(builder: _buildFeedback),
              onDragStarted: () {
                setState(() => _dragging = true);
                onBoardDragStarted();
              },
              onDragUpdate: onBoardDragUpdate,
              onDragEnd: (_) {
                if (mounted) setState(() => _dragging = false);
                onBoardDragEnd();
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: header,
              ),
            ),
          ),
          if (candidates.isNotEmpty) const DropIndicator(),
        ],
      ),
    );
  }

  Widget _buildFeedback(BuildContext context) {
    // Freeze the column at its current size; the overlay it is painted in
    // does not constrain its height.
    return Transform.translate(
      offset: -_grabOffset,
      child: Transform.rotate(
        angle: 0.03,
        alignment: Alignment.topLeft,
        child: Material(
          type: MaterialType.transparency,
          elevation: 12,
          child: SizedBox.fromSize(
            size: _size,
            child: Opacity(
              opacity: 0.92,
              child: ListColumn(
                list: list,
                index: widget.index,
                controller: controller,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCards(BuildContext context) {
    return DragAutoScroller(
      controller: _scroll,
      axis: Axis.vertical,
      child: Scrollbar(
        controller: _scroll,
        child: ListView.builder(
          controller: _scroll,
          shrinkWrap: true,
          itemCount: list.cards.length,
          itemBuilder: (context, index) {
            final card = list.cards[index];
            return DraggableCard(
              key: ValueKey(card.id),
              card: card,
              listId: list.id,
              index: index,
              controller: controller,
              onTap: () => _openCard(context, card),
            );
          },
        ),
      ),
    );
  }

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
}

/// A card that can be dragged and that accepts other cards dropped on it.
class DraggableCard extends StatefulWidget {
  const DraggableCard({
    super.key,
    required this.card,
    required this.listId,
    required this.index,
    required this.controller,
    this.onTap,
  });

  final TaskCard card;
  final String listId;

  /// Position of [card] inside its list.
  final int index;
  final BoardController controller;
  final VoidCallback? onTap;

  static const gap = 8.0;

  @override
  State<DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard> with BoardDragCallbacks {
  Offset _grabOffset = Offset.zero;
  Size _size = Size.zero;
  DropSide? _side;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final tile = CardTile(card: card, onTap: widget.onTap);

    return DragTarget<CardDragData>(
      onMove: (details) {
        final box = context.findRenderObject()! as RenderBox;
        final side = DropSide.fromPosition(
          box.globalToLocal(details.offset).dy,
          box.size.height,
        );
        if (side != _side) setState(() => _side = side);
      },
      onLeave: (_) => setState(() => _side = null),
      onAcceptWithDetails: (details) {
        final slot = widget.index + (_side == DropSide.after ? 1 : 0);
        setState(() => _side = null);
        widget.controller.moveCard(details.data.cardId, widget.listId, slot);
      },
      builder: (context, candidates, _) {
        final hovering =
            candidates.isNotEmpty && candidates.first?.cardId != card.id;
        final side = hovering ? _side : null;
        // Each card owns half of the gap above and below it, so the
        // indicator for "after A" and "before B" is drawn at the same spot.
        const inset = -DropIndicator.thickness / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DraggableCard.gap / 2,
              ),
              child: Listener(
                onPointerDown: (event) {
                  _grabOffset = event.localPosition;
                  _size = context.size!;
                },
                child: BoardDraggable<CardDragData>(
                  data: CardDragData(card.id),
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  onDragStarted: onBoardDragStarted,
                  onDragUpdate: onBoardDragUpdate,
                  onDragEnd: (_) => onBoardDragEnd(),
                  // Built lazily so it picks up the grab point recorded above.
                  feedback: Builder(
                    builder: (_) => Transform.translate(
                      offset: -_grabOffset,
                      child: Transform.rotate(
                        angle: 0.04,
                        child: SizedBox(
                          width: _size.width,
                          child: CardTile(card: card, elevated: true),
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.35, child: tile),
                  child: tile,
                ),
              ),
            ),
            if (side != null)
              Positioned(
                left: 0,
                right: 0,
                top: side == DropSide.before ? inset : null,
                bottom: side == DropSide.after ? inset : null,
                child: const DropIndicator(),
              ),
          ],
        );
      },
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
