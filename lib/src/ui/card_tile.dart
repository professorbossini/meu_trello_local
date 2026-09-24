import 'package:flutter/material.dart';

import '../board/models.dart';

/// Visual representation of a [TaskCard].
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    this.onTap,
    this.elevated = false,
  });

  final TaskCard card;
  final VoidCallback? onTap;

  /// Lifts the card, used for the drag feedback.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasDescription = card.description.trim().isNotEmpty;

    return Material(
      color: colors.surface,
      elevation: elevated ? 8 : 1,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.title, style: theme.textTheme.bodyMedium),
              if (hasDescription) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 14, color: colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        card.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
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
    );
  }
}
