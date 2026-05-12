import 'package:flutter/material.dart';
import 'home_page.dart';
import 'skill_page.dart';
import 'portfolio_checker_page.dart';
import 'cv_checker_page.dart';
import 'skill_matching_page.dart';
import 'projects_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isDark = t.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(onNavigateToTab: _onTabSelected),
          const SkillPage(),
          const PortfolioCheckerPage(),
          const CvCheckerPage(),
          const SkillMatchingPage(),
          const ProjectsPage(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: t.dividerColor, width: 0.5)),
          boxShadow: isDark
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_filled, Icons.home_outlined, 'Home', 0),
              _buildNavItem(Icons.list, Icons.list, 'Skills', 1),
              _buildNavItem(Icons.work, Icons.work_outline, 'Portfolio', 2),
              _buildNavItem(Icons.description, Icons.description_outlined, 'CV', 3),
              _buildNavItem(Icons.track_changes, Icons.track_changes, 'Match', 4),
              _buildNavItem(Icons.folder, Icons.folder_outlined, 'Projects', 5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData activeIcon, IconData inactiveIcon, String label, int index) {
    final isActive = _currentIndex == index;
    final cs = Theme.of(context).colorScheme;
    final color = isActive ? cs.primary : cs.onSurface.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: () => _onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? activeIcon : inactiveIcon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}
