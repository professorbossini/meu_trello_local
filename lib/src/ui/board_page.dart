import 'package:flutter/material.dart';

import '../board/board_controller.dart';
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
      body: DecoratedBox(
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
    );
  }

  Widget _buildLists(BuildContext context) {
    final lists = widget.controller.board.lists;
    return Scrollbar(
      controller: _horizontal,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final list in lists) ...[
              ListColumn(
                key: ValueKey(list.id),
                list: list,
                controller: widget.controller,
              ),
              const SizedBox(width: 12),
            ],
            _AddListColumn(onSubmit: widget.controller.addList),
          ],
        ),
      ),
    );
  }
}

class _AddListColumn extends StatelessWidget {
  const _AddListColumn({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
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
