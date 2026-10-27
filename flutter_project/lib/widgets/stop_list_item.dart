import 'package:flutter/material.dart';
import '../models/bus_stop.dart';
import '../services/favorites_service.dart';

class StopListItem extends StatefulWidget {
  final BusStop stop;
  final VoidCallback onSelect;
  final VoidCallback? onStarToggled;
  final VoidCallback? onDelete;
  final bool confirmBeforeUnstar;

  const StopListItem({
    super.key,
    required this.stop,
    required this.onSelect,
    this.onStarToggled,
    this.onDelete,
    this.confirmBeforeUnstar = false,
  });

  @override
  State<StopListItem> createState() => _StopListItemState();
}

class _StopListItemState extends State<StopListItem> {
  bool _starred = false;

  @override
  void initState() {
    super.initState();
    _starred = FavoritesService.isStarredSync(widget.stop.code) ?? false;
    _loadStarred();
  }

  @override
  void didUpdateWidget(covariant StopListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stop.code != widget.stop.code) {
      _loadStarred();
    }
  }

  Future<void> _loadStarred() async {
    final s = await FavoritesService.isStarred(widget.stop.code);
    if (mounted) {
      setState(() => _starred = s);
    }
  }

  Future<bool> _showConfirmDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF151C2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE11D48),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remove Bus Stop?',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${widget.stop.name} (${widget.stop.code})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove ${widget.stop.name} from this list?',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _handleStarClick() async {
    if (_starred && widget.confirmBeforeUnstar && widget.onDelete != null) {
      final confirmed = await _showConfirmDeleteDialog();
      if (confirmed) {
        widget.onDelete!();
      }
      return;
    }

    final nowStarred = await FavoritesService.toggleStarred(
      widget.stop.code,
      customName: widget.stop.name,
    );
    if (mounted) {
      setState(() => _starred = nowStarred);
    }
    widget.onStarToggled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardContent = Card(
      elevation: 0,
      color: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: widget.onSelect,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: Bus stop name
                    Text(
                      widget.stop.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Line 2: bus stop code | road name
                    Row(
                      children: [
                        Text(
                          widget.stop.code,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '|',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.stop.road,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.stop.distanceMeters != null) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.place_rounded,
                            size: 12,
                            color: Color(0xFFE11D48),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            widget.stop.distanceMeters! < 1000
                                ? '${widget.stop.distanceMeters}m'
                                : '${(widget.stop.distanceMeters! / 1000).toStringAsFixed(1)}km',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Line 3: Bus services preview pill row
                    if (widget.stop.services.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...widget.stop.services.take(7).map(
                                  (svc) => Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.black12,
                                      ),
                                    ),
                                    child: Text(
                                      svc,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            if (widget.stop.services.length > 7)
                              Text(
                                '+${widget.stop.services.length - 7}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Star Button & Chevron
              InkWell(
                onTap: _handleStarClick,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _starred
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.14)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _starred ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: _starred
                        ? const Color(0xFFF59E0B)
                        : theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.onDelete == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: cardContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: ValueKey('swipe-${widget.stop.code}'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (_) => _showConfirmDeleteDialog(),
          onDismissed: (_) => widget.onDelete?.call(),
          background: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerLeft,
            child: const Row(
              children: [
                Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 18),
              ],
            ),
          ),
          child: cardContent,
        ),
      ),
    );
  }
}
