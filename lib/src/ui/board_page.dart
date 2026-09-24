import 'package:flutter/material.dart';

import '../board/board_controller.dart';
import 'drag_and_drop.dart';
import 'inline_composer.dart';
import 'list_column.dart';
import 'theme.dart';

/// The main screen: a horizontally scrolling row of lists.
class BoardPage extends StatefulWidget {
  const BoardPage({super.key, required this.controller});

  final BoardController controller;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fill the whole window so the background and the scroll area span it
      // even when the lists are short.
      body: SizedBox.expand(
        child: Stack(
          children: [
            const Positioned.fill(child: _Aura()),
            SafeArea(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(controller: widget.controller),
                    Expanded(child: _buildLists(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _padding = EdgeInsets.fromLTRB(16, 8, 16, 24);

  Widget _buildLists(BuildContext context) {
    final lists = widget.controller.board.lists;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = BoardLayout.compute(
          constraints.maxWidth - _padding.horizontal,
          lists.length + 1,
        );
        return DragAutoScroller(
          controller: _scroll,
          axis: Axis.vertical,
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: _padding,
              child: Wrap(
                spacing: BoardLayout.gap,
                runSpacing: BoardLayout.gap,
                children: [
                  for (final (index, list) in lists.indexed)
                    ListColumn(
                      key: ValueKey(list.id),
                      list: list,
                      index: index,
                      controller: widget.controller,
                      width: layout.columnWidth,
                      stacked: layout.stacked,
                    ),
                  _AddListColumn(
                    width: layout.columnWidth,
                    stacked: layout.stacked,
                    onSubmit: widget.controller.addList,
                    onListDropped: (listId) =>
                        widget.controller.moveList(listId, lists.length),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddListColumn extends StatelessWidget {
  const _AddListColumn({
    required this.width,
    required this.stacked,
    required this.onSubmit,
    required this.onListDropped,
  });

  final double width;
  final bool stacked;
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
          if (candidates.isNotEmpty && stacked)
            const Positioned(
              left: 0,
              right: 0,
              top: -(BoardLayout.gap + DropIndicator.thickness) / 2,
              child: DropIndicator(),
            )
          else if (candidates.isNotEmpty)
            const Positioned(
              top: 0,
              bottom: 0,
              left: -(BoardLayout.gap + DropIndicator.thickness) / 2,
              child: DropIndicator(axis: Axis.vertical),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
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

/// Title in the accent gradient with a live summary of the board.
class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final BoardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lists = controller.board.lists;
    final cards = lists.fold(0, (sum, list) => sum + list.cards.length);
    String plural(int n, String one, String many) =>
        n == 1 ? '1 $one' : '$n $many';
    final summary =
        '${plural(lists.length, 'lista', 'listas')} · '
        '${plural(cards, 'tarefa', 'tarefas')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'Minhas Tarefas',
            style: theme.textTheme.headlineMedium?.withWeight(FontWeight.w500),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: Motion.medium,
            switchInCurve: Motion.emphasized,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: Text(
              summary,
              key: ValueKey(summary),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft glow of the accent colors behind the board.
class _Aura extends StatelessWidget {
  const _Aura();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget glow(Alignment center, Color color, double alpha) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: 1.1,
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          glow(
            const Alignment(-1, -1.2),
            AppTheme.gradientColors[0],
            dark ? 0.16 : 0.10,
          ),
          glow(
            const Alignment(1, -1.2),
            AppTheme.gradientColors[2],
            dark ? 0.12 : 0.08,
          ),
        ],
      ),
    );
  }
}
