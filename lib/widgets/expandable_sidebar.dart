import 'package:flutter/material.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const SidebarItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class ExpandableSidebar extends StatefulWidget {
  final List<SidebarItem> items;

  const ExpandableSidebar({
    super.key,
    required this.items,
  });

  @override
  State<ExpandableSidebar> createState() => _ExpandableSidebarState();
}

class _ExpandableSidebarState extends State<ExpandableSidebar>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  static const double _menuWidth = 200.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: _menuWidth, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _isOpen = true);
    _controller.forward();
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scrim overlay
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) => Container(
                  color: Colors.black.withValues(alpha: _fadeAnimation.value * 0.4),
                ),
              ),
            ),
          ),

        // Slide-in menu panel
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return Positioned(
              left: -_slideAnimation.value,
              top: 0,
              bottom: 0,
              width: _menuWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(4, 0),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Close button at top — same position as hamburger
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 22),
                          onPressed: _close,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Menu items — top aligned
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: widget.items.map(_buildMenuItem).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Hamburger button — only visible when menu is closed
        if (!_isOpen)
          Positioned(
            left: 16,
            top: 16,
            child: GestureDetector(
              onTap: _open,
              child: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuItem(SidebarItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _close();
            item.onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: item.color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(item.icon, color: item.color, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
