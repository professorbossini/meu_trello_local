import 'package:flutter/material.dart';

import '../board/board_controller.dart';
import '../board/models.dart';
import 'card_tile.dart';
import 'dialogs.dart';
import 'drag_and_drop.dart';
import 'feedback.dart';
import 'inline_composer.dart';
import 'theme.dart';

/// How the board lays its columns out for a given width.
///
/// Columns sit side by side while they fit; the ones that don't wrap onto
/// new rows, down to a single column per row on narrow windows. Nothing is
/// ever hidden, so every list stays reachable for drag and drop.
@immutable
class BoardLayout {
  const BoardLayout({required this.columnsPerRow, required this.columnWidth});

  /// Lays out [itemCount] columns (the lists plus the "add list" column)
  /// across [availableWidth] pixels.
  factory BoardLayout.compute(double availableWidth, int itemCount) {
    final fitting = ((availableWidth + gap) / (minColumnWidth + gap)).floor();
    final columns = fitting.clamp(1, itemCount < 1 ? 1 : itemCount);
    final width = (availableWidth - gap * (columns - 1)) / columns;
    return BoardLayout(
      columnsPerRow: columns,
      columnWidth: width.clamp(0, maxColumnWidth).toDouble(),
    );
  }

  static const gap = 12.0;
  static const minColumnWidth = 260.0;
  static const maxColumnWidth = 340.0;

  final int columnsPerRow;
  final double columnWidth;

  /// Whether lists are stacked one per row.
  bool get stacked => columnsPerRow == 1;

  @override
  bool operator ==(Object other) =>
      other is BoardLayout &&
      other.columnsPerRow == columnsPerRow &&
      other.columnWidth == columnWidth;

  @override
  int get hashCode => Object.hash(columnsPerRow, columnWidth);

  @override
  String toString() => 'BoardLayout($columnsPerRow x $columnWidth)';
}

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
    required this.width,
    this.stacked = false,
  });

  final TaskList list;
  final double width;

  /// Whether lists are stacked vertically, one per row. Lists dropped here
  /// then land above or below this one instead of to its left or right.
  final bool stacked;

  /// Position of [list] on the board.
  final int index;
  final BoardController controller;

  @override
  State<ListColumn> createState() => _ListColumnState();
}

class _ListColumnState extends State<ListColumn> with BoardDragCallbacks {
  bool _dragging = false;
  bool _hovered = false;
  Offset _grabOffset = Offset.zero;
  Size _size = Size.zero;
  DropSide? _listDropSide;

  TaskList get list => widget.list;
  BoardController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return DragTarget<ListDragData>(
      onWillAcceptWithDetails: (details) => details.data.listId != list.id,
      onMove: (details) {
        final box = context.findRenderObject()! as RenderBox;
        final local = box.globalToLocal(details.offset);
        final side = widget.stacked
            ? DropSide.fromPosition(local.dy, box.size.height)
            : DropSide.fromPosition(local.dx, box.size.width);
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
        // Center the line in the gap between columns.
        const inset = -(BoardLayout.gap + DropIndicator.thickness) / 2;
        final before = side == DropSide.before;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              opacity: _dragging ? 0.3 : 1,
              duration: Motion.short,
              curve: Motion.standard,
              child: _buildColumn(context),
            ),
            if (side != null && widget.stacked)
              Positioned(
                left: 0,
                right: 0,
                top: before ? inset : null,
                bottom: before ? null : inset,
                child: const DropIndicator(),
              )
            else if (side != null)
              Positioned(
                top: 0,
                bottom: 0,
                left: before ? inset : null,
                right: before ? null : inset,
                child: const DropIndicator(axis: Axis.vertical),
              ),
          ],
        );
      },
    );
  }

  Widget _buildColumn(BuildContext context) {
    final activity = BoardDragActivity.of(context);
    return DragTarget<CardDragData>(
      onAcceptWithDetails: (details) =>
          controller.moveCard(details.data.cardId, list.id, list.cards.length),
      builder: (context, candidates, _) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: ListenableBuilder(
          listenable: activity,
          builder: (context, _) {
            // Tint the column a card would land in.
            final receiving = _hovered && activity.payload is CardDragData;
            return _buildBody(context, receiving, candidates.isNotEmpty);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool receiving, bool dropAtEnd) {
    // The width follows the window directly; animating it would lag behind
    // while the window is being resized.
    return SizedBox(
      width: widget.width,
      child: _buildDecoratedBody(context, receiving, dropAtEnd),
    );
  }

  Widget _buildDecoratedBody(
    BuildContext context,
    bool receiving,
    bool dropAtEnd,
  ) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.emphasized,
      decoration: BoxDecoration(
        color: receiving
            ? Color.alphaBlend(
                colors.primary.withValues(alpha: 0.08),
                colors.surfaceContainer,
              )
            : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          width: 1.5,
          color: receiving
              ? colors.primary.withValues(alpha: 0.45)
              : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          if (list.cards.isEmpty)
            _EmptyListHint(receiving: receiving)
          else
            _buildCards(context),
          if (dropAtEnd && list.cards.isNotEmpty) ...[
            const SizedBox(height: 2),
            const DropIndicator(),
          ],
          const SizedBox(height: 6),
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
                onBoardDragStarted(ListDragData(list.id));
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
      child: Lift(
        angle: 0.02,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gradientColors[1].withValues(alpha: 0.3),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SizedBox.fromSize(
            size: _size,
            child: Material(
              type: MaterialType.transparency,
              child: ListColumn(
                list: list,
                index: widget.index,
                controller: controller,
                width: widget.width,
                stacked: widget.stacked,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The cards grow the column; the board scrolls as a whole.
  Widget _buildCards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, card) in list.cards.indexed)
          DraggableCard(
            key: ValueKey(card.id),
            card: card,
            listId: list.id,
            index: index,
            controller: controller,
            onTap: () => _openCard(context, card),
          ),
      ],
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
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        final undo = controller.removeCard(card.id);
        showUndoSnackBar(messenger, message: 'Tarefa excluída', onUndo: undo);
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
          // Let the card fill the column width.
          fit: StackFit.passthrough,
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
                  onDragStarted: () =>
                      onBoardDragStarted(CardDragData(card.id)),
                  onDragUpdate: onBoardDragUpdate,
                  onDragEnd: (_) => onBoardDragEnd(),
                  // Built lazily so it picks up the grab point recorded above.
                  feedback: Builder(
                    builder: (_) => Transform.translate(
                      offset: -_grabOffset,
                      child: Lift(
                        child: SizedBox(
                          width: _size.width,
                          child: CardTile(card: card, lifted: true),
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: _CardSlot(child: tile),
                  child: Appear(child: tile),
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

  void _delete(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final undo = controller.removeList(list.id);
    showUndoSnackBar(
      messenger,
      message: 'Lista "${list.title}" excluída',
      onUndo: undo,
    );
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
              padding: const EdgeInsets.fromLTRB(8, 10, 0, 10),
              child: Text(
                list.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.withWeight(FontWeight.w500),
              ),
            ),
          ),
        ),
        _CountBadge(count: list.cards.length),
        PopupMenuButton<_ListAction>(
          tooltip: 'Ações da lista',
          icon: const Icon(Icons.more_horiz_rounded, size: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedSwitcher(
        duration: Motion.medium,
        switchInCurve: Motion.emphasized,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Text(
          '$count',
          key: ValueKey(count),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: colors.onSecondaryContainer),
        ),
      ),
    );
  }
}

/// Keeps a dragged card's place in its list, outlined like an empty slot.
class _CardSlot extends StatelessWidget {
  const _CardSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CardTile.radius),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Opacity(opacity: 0, child: child),
    );
  }
}

/// Placeholder shown in a list without cards.
class _EmptyListHint extends StatelessWidget {
  const _EmptyListHint({required this.receiving});

  /// Whether a card is being dragged over the list.
  final bool receiving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.emphasized,
      height: receiving ? 72 : 56,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CardTile.radius),
        border: Border.all(
          color: receiving
              ? colors.primary.withValues(alpha: 0.6)
              : colors.outlineVariant,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: Motion.short,
        child: Text(
          receiving ? 'Solte aqui' : 'Nenhuma tarefa',
          key: ValueKey(receiving),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: receiving ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
