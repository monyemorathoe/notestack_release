import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:notestack/providers/checklist_provider.dart';
import '../models/checklist_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late TextEditingController _titleController;
  late FocusNode _titleFocusNode;
  late ScrollController _scrollController;

  bool _swipeToDeleteChecklistsEnabled = false;
  static const String _kSwipeToDeleteChecklists = 'swipeToDeleteChecklists';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _titleFocusNode = FocusNode();
    _scrollController = ScrollController();
    _loadSettings();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _swipeToDeleteChecklistsEnabled = prefs.getBool(_kSwipeToDeleteChecklists) ?? false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _scrollController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _addItem() {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      Provider.of<ChecklistProvider>(context, listen: false).addItem(title);
      _titleController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Widget _buildChecklistItem(ChecklistItem item, int itemIndex, ChecklistProvider provider, ThemeData theme, bool isDragging) {
    Color cardBackgroundColor = isDragging
        ? theme.colorScheme.primaryContainer.withOpacity(0.5)
        : (theme.cardTheme.color ?? theme.cardColor);
    
    TextStyle titleStyle = TextStyle(
      decoration: item.isDone ? TextDecoration.lineThrough : null,
      color: item.isDone ? Colors.grey : (theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface),
      fontSize: 16,
      fontWeight: FontWeight.normal,
    );

    // Visual drag handle icon with padding
    Widget dragHandleIcon = const Padding(
      padding: EdgeInsets.all(10.0), // Padding for the drag handle icon
      child: Icon(Icons.drag_handle),
    );

    List<Widget> trailingWidgets = [];
    if (!_swipeToDeleteChecklistsEnabled) {
      trailingWidgets.add(
        IconButton(
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error.withOpacity(0.8)),
          tooltip: 'Delete Task',
          onPressed: () {
            final itemTitle = item.title; 
            provider.deleteItem(item.id);
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"$itemTitle" deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    provider.undoDeleteItem();
                  },
                ),
              ),
            );
          },
          splashRadius: 24.0,
        ),
      );
      // If swipe is OFF, wrap the handle icon with ReorderableDragStartListener
      trailingWidgets.add(ReorderableDragStartListener(index: itemIndex, child: dragHandleIcon));
    } else {
      // If swipe is ON, just add the visual handle icon. Dragging is handled by an outer listener.
      trailingWidgets.add(dragHandleIcon);
    }

    Widget itemContent = Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: cardBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: isDragging ? 4.0 : (theme.cardTheme.elevation ?? 1.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => provider.toggleDone(item.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => provider.toggleDone(item.id),
                child: Icon(
                  item.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: item.isDone ? theme.colorScheme.primary : theme.iconTheme.color?.withOpacity(0.7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.title,
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...trailingWidgets, // Add the prepared trailing widgets
            ],
          ),
        ),
      ),
    );

    if (_swipeToDeleteChecklistsEnabled && !isDragging) {
      // When swipe is enabled, wrap the itemContent (which includes the visual handle)
      // with Dismissible, and then wrap Dismissible with ReorderableDragStartListener
      // to make the whole item area draggable.
      return ReorderableDragStartListener(
        index: itemIndex,
        child: Dismissible(
          key: ValueKey(item.id),
          background: Container(
            color: theme.colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: Icon(Icons.delete_sweep_outlined, color: theme.colorScheme.onErrorContainer),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            final itemTitle = item.title; 
            provider.deleteItem(item.id);
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"$itemTitle" deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    provider.undoDeleteItem();
                  },
                ),
              ),
            );
          },
          child: itemContent,
        ),
      );
    }
    // If swipe is not enabled, or if it's the proxy decorator, return itemContent directly.
    // The ReorderableDragStartListener around dragHandleIcon (in trailingWidgets) handles dragging.
    return itemContent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: const [],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChecklistProvider>(
              builder: (context, provider, child) {
                final items = provider.items;
                if (items.isEmpty && _titleController.text.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No tasks yet. Use the field below to add one!',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ReorderableListView.builder(
                  buildDefaultDragHandles: false, 
                  scrollController: _scrollController,
                  padding: const EdgeInsets.only(top: 4.0, bottom: 80.0), 
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    Widget listItemWidget = _buildChecklistItem(item, index, provider, theme, false);
                    return KeyedSubtree(key: ValueKey(item.id), child: listItemWidget);
                  },
                  onReorder: (oldIndex, newIndex) {
                    Provider.of<ChecklistProvider>(context, listen: false).reorderItem(oldIndex, newIndex);
                  },
                  proxyDecorator: (Widget child, int index, Animation<double> animation) {
                    final itemsFromProvider = Provider.of<ChecklistProvider>(context, listen: false).items; 
                    if (index < 0 || index >= itemsFromProvider.length) {
                      return child; 
                    }
                    final item = itemsFromProvider[index];
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (BuildContext context, Widget? _child) {
                        return _buildChecklistItem(item, index, Provider.of<ChecklistProvider>(context, listen: false), theme, true);
                      },
                      child: child,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8.0),
                color: theme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                  child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'Add a new task...',
                          border: InputBorder.none,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _addItem(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: theme.colorScheme.primary,
                      tooltip: 'Add Task',
                      iconSize: 28.0,
                      onPressed: _addItem,
                    ),
                  ],
                ),
              )
            )
          ),
        ],
      ),
    );
  }
}
