import 'package:flutter/material.dart';
import 'feed_screen.dart';
import 'discover_screen.dart';
import 'teams_screen.dart';
import 'profile_screen.dart';
import 'package:kritun/features/messages/presentation/dm_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final _screens = const [
    FeedScreen(),
    DiscoverScreen(),
    TeamsScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // ⭐ Middle button → Messages
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DMListScreen()),
      );
      return;
    }

    setState(() {
      _currentIndex = index > 2 ? index - 1 : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visualIndex = _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex;

    return Scaffold(
      body: _screens[_currentIndex],

      /// 🔥 CUSTOM NAV BAR WITH POP-OUT BUTTON
      bottomNavigationBar: SizedBox(
        height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            /// NAV BAR
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomNavigationBar(
                currentIndex: visualIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                showSelectedLabels: false,
                showUnselectedLabels: false,
                backgroundColor: Colors.black,
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.grey,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    label: 'Feed',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search),
                    label: 'Discover',
                  ),
                  BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.group_outlined),
                    label: 'Teams',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    label: 'Profile',
                  ),
                ],
              ),
            ),

            /// 🕳️ NAV BAR NOTCH BASE (THIS MAKES IT FEEL ATTACHED)
            Positioned(
              bottom: 22,
              child: Container(
                height: 74,
                width: 74,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black, // SAME as nav bar
                ),
              ),
            ),

            /// ⭐ CENTER MESSAGE BUTTON
            Positioned(
              bottom: 30,
              child: GestureDetector(
                onTap: () => _onItemTapped(2),
                child: Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF141414),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
