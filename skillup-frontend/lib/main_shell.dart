import 'package:flutter/material.dart';
import 'home_page.dart';
import 'skill_page.dart';
import 'projects_page.dart';
import 'cv_checker_page.dart';
import 'portfolio_checker_page.dart';
import 'skill_matching_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 1; // 0=Skills, 1=Home, 2=Projects

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
          const SkillPage(),
          HomePage(
            onNavigateToTab: (index) {
              if (index == 3) _openPage(const CvCheckerPage());
              else if (index == 4) _openPage(const PortfolioCheckerPage());
              else if (index == 5) _openPage(const SkillMatchingPage());
              else _onTabSelected(index);
            },
          ),
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
              _buildNavItem(Icons.list, Icons.list_outlined, 0),
              _buildNavItem(Icons.home_filled, Icons.home_outlined, 1),
              _buildNavItem(Icons.folder, Icons.folder_outlined, 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData activeIcon, IconData inactiveIcon, int index) {
    final isActive = _currentIndex == index;
    final cs = Theme.of(context).colorScheme;
    final color = isActive ? cs.primary : cs.onSurface.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: () => _onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Icon(isActive ? activeIcon : inactiveIcon, color: color, size: 28),
      ),
    );
  }
}
