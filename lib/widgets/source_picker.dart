import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Vertical-dots menu button that lists the four supported sources(BBC,.
/// Kept as its own widget so the PopupMenu's glass-styled shape/color
/// (set via `PopupMenuTheme` in main.dart) is easy to reuse elsewhere.
class SourcePicker extends StatelessWidget {
  final NewsSource selected;
  final ValueChanged<NewsSource> onSelected;

  const SourcePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NewsSource>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      tooltip: 'Change source',
      onSelected: onSelected,
      itemBuilder: (context) => NewsSource.all.map((source) {
        final isSelected = source.sourceId == selected.sourceId;
        return PopupMenuItem<NewsSource>(
          value: source,
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: isSelected ? Colors.deepPurple : Colors.grey,
              ),
              const SizedBox(width: 10),
              Text(source.displayName),
            ],
          ),
        );
      }).toList(),
    );
  }
}
