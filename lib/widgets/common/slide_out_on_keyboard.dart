import 'package:flutter/material.dart';

class SlideOutOnKeyboard extends StatefulWidget {
  const SlideOutOnKeyboard({
    super.key,
    required this.child,
    this.enable = true,
    this.duration = const Duration(milliseconds: 100),
  });

  final Widget child;
  final bool enable;
  final Duration duration;

  @override
  State<SlideOutOnKeyboard> createState() => _SlideOutOnKeyboardState();
}

class _SlideOutOnKeyboardState extends State<SlideOutOnKeyboard> {
  bool _isKeyboardVisible = false;

  void _onFocusChange() {
    if (!widget.enable) {
      return;
    }

    final viewInsets = EdgeInsets.fromViewPadding(
      View.of(context).viewInsets,
      View.of(context).devicePixelRatio,
    );
    final isKeyboardVisible = viewInsets.bottom > 0;

    if (isKeyboardVisible != _isKeyboardVisible) {
      setState(() => _isKeyboardVisible = isKeyboardVisible);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFocusChange());

    if (!widget.enable) {
      return widget.child;
    }

    return AnimatedSwitcher(
      duration: widget.duration,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: child,
      ),
      child: _isKeyboardVisible
          ? const SizedBox.shrink()
          : Align(
              key: const ValueKey('keyboard-visible-false'),
              alignment: Alignment.bottomCenter,
              child: widget.child,
            ),
    );
  }
}
