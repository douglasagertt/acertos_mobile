import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/owner.dart';

/// A tappable owner chip. Inactive pills all look the same neutral grey;
/// the active one is colored per-owner (Bruna=lavender, Douglas=salvia,
/// Compartilhado=a third accent purple with a group icon, Ignorar=muted).
class OwnerPill extends StatelessWidget {
  const OwnerPill({super.key, required this.owner, required this.active, required this.onTap, this.label});

  final Owner owner;
  final bool active;
  final VoidCallback onTap;

  /// Overrides the displayed text; defaults to [Owner.label]. Used where the
  /// same owner/color needs different wording (e.g. a "Ignorados" filter
  /// chip vs. the "Ignorar" per-row action).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = !active
        ? (AppColors.surfaceVariant, AppColors.onSurfaceVariant)
        : switch (owner) {
            Owner.bruna => (AppColors.lavender, Colors.white),
            Owner.douglas => (AppColors.salvia, Colors.white),
            Owner.compartilhado => (AppColors.primaryContainer, AppColors.onPrimaryContainer),
            Owner.ignorar => (AppColors.outlineVariant, AppColors.onSurfaceVariant),
          };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (owner == Owner.compartilhado) ...[
              Icon(Icons.group, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(label ?? owner.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
          ],
        ),
      ),
    );
  }
}
