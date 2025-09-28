import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:notestack/services/secure_storage_service.dart';
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
  final SecureStorageService _secureStorageService = SecureStorageService();

  String _getPlainTextFromDelta(String deltaJson) {
    if (deltaJson.isEmpty) {
      return 'No content';
    }
    try {
      final List<dynamic> jsonData = jsonDecode(deltaJson);
      final doc = Document.fromJson(jsonData);
      return doc.toPlainText().trim().isNotEmpty ? doc.toPlainText().trim() : 'No content';
    } catch (e) {
      // If it's not valid JSON, it might be old plain text data
      return deltaJson.trim().isNotEmpty ? deltaJson.trim() : 'No content';
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);
    final isSelected = noteProvider.isNoteSelected(widget.note.id);
    final theme = Theme.of(context);

    Color cCardbackground; // Effective card background color
    Color cTitletext; // Effective color for title
    Color cSubtitletext; // Effective color for subtitle/content preview
    Color cDatetext; // Effective color for date
    Color cStatusicon; // Effective color for status icons (pin, lock)

    bool hasCustomNoteColor = widget.note.colorValue != null;

    if (hasCustomNoteColor) {
      final noteColor = Color(widget.note.colorValue!);
      if (theme.brightness == Brightness.dark) {
        // Dark Mode: Blend note color with a dark surface
        cCardbackground = Color.alphaBlend(noteColor.withAlpha((255 * 0.4).round()), theme.cardTheme.color ?? theme.cardColor);
      } else {
        // Light Mode: Use note color, maybe with slight transparency if it can be too vivid
        cCardbackground = noteColor.withAlpha((255 * 0.85).round()); // Adjust opacity as needed
      }

      // Determine text/icon colors based on the contrast with C_cardBackground
      final cardBrightness = ThemeData.estimateBrightnessForColor(cCardbackground);
      if (cardBrightness == Brightness.dark) {
        cTitletext = Colors.white;
        cSubtitletext = Colors.white70;
        cDatetext = Colors.white60;
        cStatusicon = Colors.white70;
      } else {
        cTitletext = Colors.black87;
        cSubtitletext = Colors.black54;
        cDatetext = Colors.black45;
        cStatusicon = Colors.black54;
      }
    } else {
      // No custom note color: Use theme defaults
      cCardbackground = theme.cardTheme.color ?? theme.cardColor;
      cTitletext = theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface;
      cSubtitletext = theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurfaceVariant;
      cDatetext = theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.8).round());
      cStatusicon = theme.colorScheme.secondary;
    }

    // Selection highlight overrides background and potentially text/icon colors
    if (isSelected) {
      cCardbackground = theme.colorScheme.primary.withAlpha(60); // More opaque selection
      final selectionBrightness = ThemeData.estimateBrightnessForColor(cCardbackground);
      if (selectionBrightness == Brightness.dark) {
        cTitletext = Colors.white;
        cSubtitletext = Colors.white70;
        cDatetext = Colors.white60;
        cStatusicon = Colors.white70;
      } else {
        // If selection color is light (e.g. light primary color)
        cTitletext = theme.colorScheme.onPrimaryContainer;
        cSubtitletext = theme.colorScheme.onPrimaryContainer.withAlpha((255 * 0.8).round());
        cDatetext = theme.colorScheme.onPrimaryContainer.withAlpha((255 * 0.7).round());
        cStatusicon = theme.colorScheme.onPrimaryContainer.withAlpha((255 * 0.8).round());
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
        statusIcons.add(Icon(Icons.push_pin, size: 20, color: cStatusicon));
      }
      if (widget.note.isLocked) {
        if (statusIcons.isNotEmpty) statusIcons.add(const SizedBox(width: 8));
        statusIcons.add(Icon(Icons.lock_outline, size: 20, color: cStatusicon));
      }
      if (statusIcons.isNotEmpty) {
        trailingWidget = Row(mainAxisSize: MainAxisSize.min, children: statusIcons);
      }
    }
    
    final plainTextContent = _getPlainTextFromDelta(widget.note.content);

    if (widget.isGridView) {
      // GridView layout: equal width/height, custom arrangement
      return AspectRatio(
        aspectRatio: 1, // Ensures the card is square or a defined aspect ratio
        child: Card(
          margin: const EdgeInsets.all(4), // Margin for grid view card
          color: cCardbackground,
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
                          Icon(Icons.push_pin, size: 20, color: cStatusicon),
                        if (widget.note.isLocked)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.lock_outline, size: 20, color: cStatusicon),
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cTitletext),
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
                                  style: TextStyle(fontStyle: FontStyle.italic, color: cSubtitletext),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : Text(
                                plainTextContent,
                                style: TextStyle(color: cSubtitletext, fontSize: 14),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      // Date at bottom
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          'Created: ${DateFormat.yMMMd().format(widget.note.createdAt)}',
                          style: TextStyle(color: cDatetext, fontSize: 12),
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
        color: cCardbackground,
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
                        style: TextStyle(fontWeight: FontWeight.bold, color: cTitletext),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      widget.note.isLocked
                          ? Text(
                              'Unlock to view content',
                              style: TextStyle(fontStyle: FontStyle.italic, color: cSubtitletext),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : Text(
                              plainTextContent,
                              style: TextStyle(color: cSubtitletext),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      const SizedBox(height: 4),
                      Text(
                        'Created: ${DateFormat.yMMMd().format(widget.note.createdAt)}',
                        style: TextStyle(color: cDatetext, fontSize: theme.textTheme.bodySmall?.fontSize),
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
