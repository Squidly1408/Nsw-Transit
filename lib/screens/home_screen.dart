import 'package:flutter/material.dart';

import '../main.dart';
import '../models/place.dart';
import '../widgets/mode_style.dart';
import 'routes_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _goTo(BuildContext context, Place p) {
    favouritesStore.addRecent(p);
    Navigator.push(context, MaterialPageRoute(builder: (_) => RoutesScreen(destination: p)));
  }

  Future<void> _search(BuildContext context) async {
    final p = await Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen(title: 'Where to?')),
    );
    if (p != null && context.mounted) _goTo(context, p);
  }

  Future<void> _addFavourite(BuildContext context) async {
    final p = await Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen(title: 'Add a favourite place')),
    );
    if (p == null || !context.mounted) return;
    final edited = await showFavouriteEditor(context, p);
    if (edited != null) await favouritesStore.addFavourite(edited);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('NSW Transit')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFavourite(context),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add place'),
      ),
      body: ListenableBuilder(
        listenable: favouritesStore,
        builder: (context, _) {
          final favs = favouritesStore.favourites;
          final recents = favouritesStore.recents;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              // Search bar
              Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(28),
                color: theme.colorScheme.surfaceContainerHigh,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => _search(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(children: [
                      Icon(Icons.search),
                      SizedBox(width: 12),
                      Text('Where to? Enter an address or stop', style: TextStyle(fontSize: 16)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Text('Favourites', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (favs.isNotEmpty)
                  Text('Hold to edit', style: theme.textTheme.bodySmall),
              ]),
              const SizedBox(height: 8),
              if (favs.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.star_border),
                    title: const Text('No favourites yet'),
                    subtitle: const Text('Save home, work or anywhere you go often.'),
                    onTap: () => _addFavourite(context),
                  ),
                )
              else
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: favouritesStore.reorder,
                  children: [
                    for (var i = 0; i < favs.length; i++)
                      Card(
                        key: ValueKey(favs[i].id),
                        child: ListTile(
                          leading: CircleAvatar(child: Icon(favouriteIcon(favs[i].icon))),
                          title: Text(favs[i].displayName),
                          subtitle: Text(favs[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle),
                          ),
                          onTap: () => _goTo(context, favs[i]),
                          onLongPress: () => _editFavourite(context, favs[i]),
                        ),
                      ),
                  ],
                ),
              if (recents.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(children: [
                  Text('Recent', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton(onPressed: favouritesStore.clearRecents, child: const Text('Clear')),
                ]),
                for (final r in recents)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text(r.name),
                    subtitle: r.subtitle == null ? null : Text(r.subtitle!, maxLines: 1),
                    trailing: IconButton(
                      icon: Icon(favouritesStore.isFavourite(r) ? Icons.star : Icons.star_border),
                      onPressed: () async {
                        final e = await showFavouriteEditor(context, r);
                        if (e != null) favouritesStore.addFavourite(e);
                      },
                    ),
                    onTap: () => _goTo(context, r),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editFavourite(BuildContext context, Place p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename / change icon'),
              onTap: () => Navigator.pop(context, 'edit')),
          ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove from favourites'),
              onTap: () => Navigator.pop(context, 'delete')),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (action == 'delete') {
      favouritesStore.removeFavourite(p);
    } else if (action == 'edit') {
      final e = await showFavouriteEditor(context, p);
      if (e != null) favouritesStore.updateFavourite(e);
    }
  }
}

/// Dialog to name a favourite and pick an icon.
Future<Place?> showFavouriteEditor(BuildContext context, Place p) {
  final ctrl = TextEditingController(text: p.label ?? '');
  var icon = p.icon;
  return showDialog<Place>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Save favourite'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name (e.g. Home, Work)'),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            for (final k in favouriteIconKeys)
              ChoiceChip(
                label: Icon(favouriteIcon(k), size: 20),
                selected: icon == k,
                onSelected: (_) => setState(() {
                  icon = k;
                  if (ctrl.text.isEmpty && (k == 'home' || k == 'work')) {
                    ctrl.text = k[0].toUpperCase() + k.substring(1);
                  }
                }),
              ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, p.copyWith(label: ctrl.text.trim(), icon: icon)),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
