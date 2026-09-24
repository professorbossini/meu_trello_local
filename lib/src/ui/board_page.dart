import 'package:flutter/material.dart';

import '../board/board_controller.dart';
import 'drag_and_drop.dart';
import 'inline_composer.dart';
import 'list_column.dart';

/// The main screen: a horizontally scrolling row of lists.
class BoardPage extends StatefulWidget {
  const BoardPage({super.key, required this.controller});

  final BoardController controller;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Trello Local'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      extendBodyBehindAppBar: true,
      // Fill the whole window so the background and the scroll area span it
      // even when the lists are short.
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.brightness == Brightness.dark
                  ? const [Color(0xFF1B2A4A), Color(0xFF3A1F4F)]
                  : const [Color(0xFF0079BF), Color(0xFF7E57C2)],
            ),
          ),
          child: SafeArea(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => _buildLists(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLists(BuildContext context) {
    final lists = widget.controller.board.lists;
    return DragAutoScroller(
      controller: _horizontal,
      axis: Axis.horizontal,
      child: Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, list) in lists.indexed) ...[
                ListColumn(
                  key: ValueKey(list.id),
                  list: list,
                  index: index,
                  controller: widget.controller,
                ),
                const SizedBox(width: 12),
              ],
              _AddListColumn(
                onSubmit: widget.controller.addList,
                onListDropped: (listId) =>
                    widget.controller.moveList(listId, lists.length),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddListColumn extends StatelessWidget {
  const _AddListColumn({required this.onSubmit, required this.onListDropped});

  final ValueChanged<String> onSubmit;

  /// Called when a list is dropped here, moving it to the end of the board.
  final ValueChanged<String> onListDropped;

  @override
  Widget build(BuildContext context) {
    return DragTarget<ListDragData>(
      onAcceptWithDetails: (details) => onListDropped(details.data.listId),
      builder: (context, candidates, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          _buildBody(context),
          if (candidates.isNotEmpty)
            const Positioned(
              top: 0,
              bottom: 0,
              left: -(12 + DropIndicator.thickness) / 2,
              child: DropIndicator(axis: Axis.vertical),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Container(
      width: listColumnWidth,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InlineComposer(
        buttonLabel: 'Adicionar outra lista',
        hintText: 'Nome da lista…',
        submitLabel: 'Adicionar lista',
        onSubmit: onSubmit,
      ),
    );
  }
}
