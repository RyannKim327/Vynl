import 'package:flutter/material.dart';

Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  String? initialName,
}) async {
  var name = initialName ?? '';

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(initialName == null ? 'New playlist' : 'Rename playlist'),
        content: TextFormField(
          initialValue: initialName,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onChanged: (value) => name = value,
          onFieldSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = name.trim();
              if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}
