// lib/widgets/top_banner.dart
import 'package:flutter/material.dart';

/// showTopBanner(context, message, isError: true/false, duration: Duration)
/// نمایش یک banner در بالای صفحه (راست-بالا) با متن، رنگ مناسب (قرمز/سبز)
/// و یک نوار پیشرفت خطی که در پایان duration به‌صورت خودکار ناپدید می‌شود.
void showTopBanner(
  BuildContext context,
  String message, {
  bool isError = true,
  Duration duration = const Duration(seconds: 15),
}) {
  final overlay = Overlay.of(context);

  //if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => TopBannerWidget(
      entry: entry,
      message: message,
      isError: isError,
      duration: duration,
    ),
  );
  overlay.insert(entry);
}

class TopBannerWidget extends StatefulWidget {
  final OverlayEntry entry;
  final String message;
  final bool isError;
  final Duration duration;

  const TopBannerWidget({
    Key? key,
    required this.entry,
    required this.message,
    required this.isError,
    required this.duration,
  }) : super(key: key);

  @override
  State<TopBannerWidget> createState() => _TopBannerWidgetState();
}

class _TopBannerWidgetState extends State<TopBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        widget.entry.remove();
      }
    });
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isError ? Colors.redAccent : Colors.green;
    final icon = widget.isError ? Icons.error_outline : Icons.check_circle;
    // Align top-right
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Material(
            // use Material so shadow/elevation works over existing UI
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: bg,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // content row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            try {
                              widget.entry.remove();
                            } catch (_) {}
                          },
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // linear timer
                  SizedBox(
                    height: 4,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        // show decreasing bar: value = 1 - controller.value
                        return LinearProgressIndicator(
                          value: 1.0 - _controller.value,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
