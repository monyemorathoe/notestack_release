import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// import 'package:parchment/parchment.dart'; // Import if needed, but likely available via Note model
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../screens/note_screen.dart';


class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback? onTap;
  final bool isGridView; // NEW: indicate grid or list view

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.isGridView = false, // default to listview
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);
    final isSelected = noteProvider.isNoteSelected(widget.note.id);
    final theme = Theme.of(context);

    // Ensure contentPreview is always a String
    final String contentPreview = widget.note.content.toPlainText().trim();

    Color cCardBackground; // Effective card background color
    Color cTitleText;      // Effective color for title
    Color cSubtitleText;   // Effective color for subtitle/content preview
    Color cDateText;       // Effective color for date
    Color cStatusIcon;     // Effective color for status icons (pin, lock)

    bool hasCustomNoteColor = widget.note.colorValue != null;

    if (hasCustomNoteColor) {
      final noteColor = Color(widget.note.colorValue!);
      if (theme.brightness == Brightness.dark) {
        // Dark Mode: Blend note color with a dark surface
        cCardBackground = Color.alphaBlend(noteColor.withAlpha((255 * 0.4).round()), theme.cardTheme.color ?? theme.cardColor);
      } else {
        // Light Mode: Use note color, maybe with slight transparency if it can be too vivid
        cCardBackground = noteColor.withAlpha((255 * 0.85).round()); // Adjust opacity as needed
      }

      // Determine text/icon colors based on the contrast with cCardBackground
      final cardBrightness = ThemeData.estimateBrightnessForColor(cCardBackground);
      if (cardBrightness == Brightness.dark) {
        cTitleText = Colors.white;
        cSubtitleText = Colors.white70;
        cDateText = Colors.white60;
        cStatusIcon = Colors.white70;
      } else {
        cTitleText = Colors.black87;
        cSubtitleText = Colors.black54;
        cDateText = Colors.black45;
        cStatusIcon = Colors.black54;
      }
    } else {
      // No custom note color: Use theme defaults
      cCardBackground = theme.cardTheme.color ?? theme.cardColor;
      cTitleText = theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface;
      cSubtitleText = theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurfaceVariant;
      cDateText = theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.8).round());
      cStatusIcon = theme.colorScheme.secondary;
    }

    // Selection highlight overrides background and potentially text/icon colors
    if (isSelected) {
      cCardBackground = theme.colorScheme.primary.withAlpha(60); // More opaque selection
      final selectionBrightness = ThemeData.estimateBrightnessForColor(cCardBackground);
      if (selectionBrightness == Brightness.dark) {
        cTitleText = Colors.white;
        cSubtitleText = Colors.white70;
        cDateText = Colors.white60;
        cStatusIcon = Colors.white70;
      } else {
        // If selection color is light (e.g. light primary color)
        cTitleText = theme.colorScheme.onPrimaryContainer;
        cSubtitleText = theme.colorScheme.onPrimaryContainer.withAlpha((255 * 0.8).round());
        cDateText = theme.colorScheme.onPrimaryContainer.withAlpha((255 * 0.7).round());
        cStatusIcon = theme.colorScheme.onPrimaryContainer.withAlpha((255 * 0.8).round());
      }
    }

    Widget? trailingWidget;
    // Remove checkbox for list view selection
    if (!widget.isGridView && noteProvider.isSelectionMode) {
      trailingWidget = null;
    } else if (noteProvider.isSelectionMode) {
      trailingWidget = Checkbox(
        value: isSelected,
        activeColor: theme.colorScheme.primary,
        checkColor: theme.colorScheme.onPrimary,
        onChanged: (bool? value) {
          noteProvider.toggleNoteSelection(widget.note.id);
        },
      );
    } else {
      List<Widget> statusIcons = [];
      if (widget.note.isPinned) {
        statusIcons.add(Icon(Icons.push_pin, size: 20, color: cStatusIcon));
      }
      if (widget.note.isLocked) {
        if (statusIcons.isNotEmpty) statusIcons.add(const SizedBox(width: 8));
        statusIcons.add(Icon(Icons.lock_outline, size: 20, color: cStatusIcon));
      }
      if (statusIcons.isNotEmpty) {
        trailingWidget = Row(mainAxisSize: MainAxisSize.min, children: statusIcons);
      }
    }

    if (widget.isGridView) {
      // GridView layout: equal width/height, custom arrangement
      return AspectRatio(
        aspectRatio: 1, // Ensures the card is square or a defined aspect ratio
        child: Card(
          margin: const EdgeInsets.all(4), // Margin for grid view card
          color: cCardBackground,
          clipBehavior: Clip.antiAlias, // Ensures InkWell splash is contained
          shape: isSelected
              ? RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(12),
                )
              : (theme.cardTheme.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: InkWell(
            borderRadius: (theme.cardTheme.shape is RoundedRectangleBorder
                ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius.resolve(Directionality.of(context))
                : BorderRadius.circular(12)),
            onTap: () async {
              if (noteProvider.isSelectionMode) {
                noteProvider.toggleNoteSelection(widget.note.id);
                return;
              }
              if (widget.onTap != null) {
                widget.onTap!();
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => NoteScreen(note: widget.note)));
            },
            onLongPress: () {
              if (widget.onTap == null && !noteProvider.isSelectionMode) {
                noteProvider.toggleNoteSelection(widget.note.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  // Status icons (pin, lock) at top right
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.note.isPinned)
                          Icon(Icons.push_pin, size: 20, color: cStatusIcon),
                        if (widget.note.isLocked)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.lock_outline, size: 20, color: cStatusIcon),
                          ),
                      ],
                    ),
                  ),
                  // Main content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Padding(
                        padding: const EdgeInsets.only(right: 32), // leave space for icons
                        child: Text(
                          widget.note.title.isEmpty ? 'Untitled' : widget.note.title,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cTitleText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Brief/content preview
                      Expanded(
                        child: widget.note.isLocked
                            ? Center(
                                child: Text(
                                  'Unlock to view content',
                                  style: TextStyle(fontStyle: FontStyle.italic, color: cSubtitleText),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : Text(
                                contentPreview.isEmpty ? 'No content' : contentPreview,
                                style: TextStyle(color: cSubtitleText, fontSize: 14),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      // Date at bottom
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          'Created: ${DateFormat.yMMMd().format(widget.note.createdAt)}',
                          style: TextStyle(color: cDateText, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // ListTile layout for normal (non-grid) view
      ShapeBorder cardShape = isSelected
          ? RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : (hasCustomNoteColor
              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              : theme.cardTheme.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)));

      BorderRadius inkWellBorderRadius = BorderRadius.circular(12); // Default for InkWell
      if (cardShape is RoundedRectangleBorder) {
        inkWellBorderRadius = cardShape.borderRadius.resolve(Directionality.of(context));
      }

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: cCardBackground,
        shape: cardShape,
        clipBehavior: Clip.antiAlias, // Ensures InkWell splash is contained
        child: InkWell(
          borderRadius: inkWellBorderRadius,
          onTap: () async {
            if (noteProvider.isSelectionMode) {
              noteProvider.toggleNoteSelection(widget.note.id);
              return;
            }
            if (widget.onTap != null) {
              widget.onTap!();
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (_) => NoteScreen(note: widget.note)));
          },
          onLongPress: () {
            if (widget.onTap == null && !noteProvider.isSelectionMode) {
              noteProvider.toggleNoteSelection(widget.note.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.note.title.isEmpty ? 'Untitled' : widget.note.title,
                        style: TextStyle(fontWeight: FontWeight.bold, color: cTitleText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      widget.note.isLocked
                          ? Text(
                              'Unlock to view content',
                              style: TextStyle(fontStyle: FontStyle.italic, color: cSubtitleText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : Text(
                              contentPreview.isEmpty ? 'No content' : contentPreview,
                              style: TextStyle(color: cSubtitleText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      const SizedBox(height: 4),
                      Text(
                        'Created: ${DateFormat.yMMMd().format(widget.note.createdAt)}',
                        style: TextStyle(color: cDateText, fontSize: theme.textTheme.bodySmall?.fontSize),
                      ),
                    ],
                  ),
                ),
                if (trailingWidget != null) ...[
                  const SizedBox(width: 8),
                  trailingWidget,
                ],
              ],
            ),
          ),
        ),
      );
    }
  }
}
