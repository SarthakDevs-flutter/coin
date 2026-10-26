import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/ports.dart';
import '../../application/providers.dart';
import '../common/widgets.dart';

/// Checks the published version gate once per launch, over the hub.
///
/// Required: a blocking prompt that only offers Update (the backend raised
/// `min_build`, e.g. for a save-format or economy fix). Optional: a prompt
/// with Later, shown once per new build.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  Future<void> _check() async {
    final s = ref.read(servicesProvider);
    final info = await s.appUpdate.check();
    if (!mounted) return;
    switch (info.urgency) {
      case UpdateUrgency.none:
        return;
      case UpdateUrgency.optional:
        final skipped = ref.read(saveProvider).settings.skippedUpdateBuild;
        if (info.latestBuild <= skipped) return;
        final update = await _prompt(info, required: false);
        if (update) {
          await s.appUpdate.startUpdate(info);
        } else {
          await ref
              .read(saveProvider.notifier)
              .updateSettings(
                (st) => st.copyWith(skippedUpdateBuild: info.latestBuild),
              );
        }
      case UpdateUrgency.required:
        // Re-prompt until the update starts; the store flow may be backed
        // out of.
        while (mounted) {
          await _prompt(info, required: true);
          await s.appUpdate.startUpdate(info);
        }
    }
  }

  Future<bool> _prompt(UpdateInfo info, {required bool required}) async {
    final l = context.l10n;
    final body = [
      required ? l.updateRequiredBody : l.updateOptionalBody,
      if (info.message case final m? when m.isNotEmpty) m,
    ].join('\n\n');
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: !required,
      builder: (ctx) => PopScope(
        canPop: !required,
        child: AlertDialog(
          title: Text(required ? l.updateRequiredTitle : l.updateOptionalTitle),
          content: Text(body),
          actions: [
            if (!required)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.updateLater),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.updateNow),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
