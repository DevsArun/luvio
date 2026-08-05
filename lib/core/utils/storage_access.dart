import 'package:flutter/material.dart';

import '../../services/permission_service.dart';

/// Shared feedback for file operations that Android's scoped storage can
/// refuse (delete / rename of files this app did not create).
///
/// Instead of the button silently doing nothing, the user is told what
/// happened and is offered a one-tap route to the "All files access" screen.
void showStorageAccessNeeded(
  BuildContext context, {
  required String action,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 7),
      content: Text(
        'Android blocked the $action. Turn on "All files access" to manage '
        'files that other apps created.',
      ),
      action: SnackBarAction(
        label: 'Allow',
        onPressed: () => PermissionService().requestAllFilesAccess(),
      ),
    ),
  );
}

/// Simple confirmation snack bar so every destructive action gives feedback.
void showActionResult(BuildContext context, String message) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
