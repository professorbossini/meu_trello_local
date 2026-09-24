import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// A button that turns into a text field for quickly adding items.
///
/// Enter submits and keeps the field open for the next entry, Escape or the
/// close button collapses it back into the button.
class InlineComposer extends StatefulWidget {
  const InlineComposer({
    super.key,
    required this.buttonLabel,
    required this.hintText,
    required this.submitLabel,
    required this.onSubmit,
    this.multiline = false,
  });

  final String buttonLabel;
  final String hintText;
  final String submitLabel;
  final ValueChanged<String> onSubmit;
  final bool multiline;

  @override
  State<InlineComposer> createState() => _InlineComposerState();
}

class _InlineComposerState extends State<InlineComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    setState(() => _open = open);
    if (open) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusNode.requestFocus(),
      );
    } else {
      _controller.clear();
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // Grow and shrink smoothly while cross-fading the two states.
    return AnimatedSize(
      duration: Motion.medium,
      curve: Motion.emphasized,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Motion.short,
        switchInCurve: Motion.emphasized,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: _open ? _buildEditor(context) : _buildButton(context),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('button'),
      onPressed: () => _setOpen(true),
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text(widget.buttonLabel),
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return CallbackShortcuts(
      key: const ValueKey('editor'),
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _setOpen(false),
        const SingleActivator(LogicalKeyboardKey.enter): _submit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            minLines: widget.multiline ? 2 : 1,
            maxLines: widget.multiline ? 4 : 1,
            decoration: InputDecoration(hintText: widget.hintText),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(
                    widget.submitLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Cancelar (Esc)',
                onPressed: () => _setOpen(false),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
