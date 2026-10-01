import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/widgets/glass_card.dart';

/// Frosted search field with a neon focus ring.
class KxSearchField extends StatefulWidget {
  const KxSearchField({super.key, required this.controller, required this.onChanged, this.hint = 'Search'});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<KxSearchField> createState() => _KxSearchFieldState();
}

class _KxSearchFieldState extends State<KxSearchField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (focused) BoxShadow(color: KxColors.cyan.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: -4),
        ],
      ),
      child: GlassCard(
        blur: true,
        radius: 16,
        padding: EdgeInsets.zero,
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: (v) {
            setState(() {});
            widget.onChanged(v);
          },
          style: KxText.body(15),
          cursorColor: KxColors.cyan,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: widget.hint,
            hintStyle: KxText.body(15, color: KxColors.textMuted),
            prefixIcon: Icon(Icons.search_rounded, color: focused ? KxColors.cyan : KxColors.textMuted),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: const Icon(Icons.close_rounded, color: KxColors.textDim, size: 20),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() {});
                      widget.onChanged('');
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}
