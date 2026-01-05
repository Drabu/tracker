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
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _widthAnimation;

  static const double _collapsedWidth = 64.0;
  static const double _expandedWidth = 180.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: _collapsedWidth,
      end: _expandedWidth,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _expand() {
    setState(() => _isExpanded = true);
    _controller.forward();
  }

  void _collapse() {
    setState(() => _isExpanded = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      right: 0,
      top: 0,
      bottom: bottomPadding,
      child: MouseRegion(
        onEnter: (_) => _expand(),
        onExit: (_) => _collapse(),
        child: AnimatedBuilder(
          animation: _widthAnimation,
          builder: (context, child) {
            return Container(
              width: _widthAnimation.value,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                border: Border(
                  left: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.items.map((item) {
                  return _buildSidebarItem(item);
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidebarItem(SidebarItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: item.color,
                  size: 18,
                ),
                Expanded(
                  child: ClipRect(
                    child: AnimatedOpacity(
                      opacity: _isExpanded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
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
                    ),
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
