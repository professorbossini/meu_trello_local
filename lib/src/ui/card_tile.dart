import 'package:flutter/material.dart';

import '../board/models.dart';
import 'theme.dart';

/// Visual representation of a [TaskCard].
///
/// Hovering lifts the card slightly; [lifted] renders it picked up, as in
/// the drag feedback, with a larger shadow tinted by the accent gradient.
class CardTile extends StatefulWidget {
  const CardTile({
    super.key,
    required this.card,
    this.onTap,
    this.lifted = false,
  });

  final TaskCard card;
  final VoidCallback? onTap;
  final bool lifted;

  static const radius = 16.0;

  @override
  State<CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<CardTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final card = widget.card;
    final hasDescription = card.description.trim().isNotEmpty;
    final raised = _hovered || widget.lifted;
    final dark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Motion.short,
        curve: Motion.emphasized,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: dark
              ? colors.surfaceContainerHigh
              : colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(CardTile.radius),
          border: Border.all(
            color: raised
                ? colors.primary.withValues(alpha: 0.35)
                : colors.outlineVariant.withValues(alpha: dark ? 0.4 : 0.6),
          ),
          boxShadow: [
            if (widget.lifted)
              BoxShadow(
                color: AppTheme.gradientColors[1].withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              )
            else if (_hovered)
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.4 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(CardTile.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            mouseCursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.3),
                  ),
                  if (hasDescription) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.notes_rounded,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            card.description.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
