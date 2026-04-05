import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'add_expenses.dart';
import 'group_page.dart';
import 'analysis.dart';
import 'profile.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _activeIndex = 0;

  static const _pages = [
    DashboardPage(),
    AddExpensePage(),
    GroupsPage(),
    AnalysisPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: IndexedStack(
        index: _activeIndex,
        children: _pages,
      ),
      bottomNavigationBar: _BottomNavBar(
        activeIndex: _activeIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddExpensePage()),
            ).then((_) => setState(() => _activeIndex = 0));
          } else {
            setState(() => _activeIndex = index);
          }
        },
      ),
    );
  }
}

// ── Bottom Nav Bar ─────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onTap;
  const _BottomNavBar({
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.add_box_outlined, Icons.add_box_rounded, 'Add'),
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Groups'),
      (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Analytics'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == activeIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  active ? items[i].$2 : items[i].$1,
                  size: 22,
                  color: active
                      ? const Color(0xFF818CF8)
                      : Colors.white.withOpacity(0.28),
                ),
                const SizedBox(height: 3),
                Text(
                  items[i].$3,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    color: active
                        ? const Color(0xFF818CF8)
                        : Colors.white.withOpacity(0.28),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}