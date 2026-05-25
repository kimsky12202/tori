import 'package:flutter/material.dart';
import 'challenge_tab_page.dart';
import 'map_page.dart';
import 'timecapsule_page.dart';
import 'setting_page.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> with SingleTickerProviderStateMixin {
  static const int _tabCount = 4;

  static const IconData _mapIcon         = Icons.map_outlined;
  static const IconData _timecapsuleIcon = Icons.hourglass_empty;
  static const IconData _challengeIcon = Icons.emoji_events_outlined;
  static const IconData _settingsIcon    = Icons.settings_outlined;

  static const ScrollPhysics _tabBarPhysics = NeverScrollableScrollPhysics();

  static const Color _primaryColor     = Color(0xFFA14040);
  static const Color _backgroundColor  = Color(0xFFF4F1EA);
  static const Color _unselectedColor  = Color(0xFF7A756D);

  TabController? controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: _tabCount, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: _buildTabBarView(),
        bottomNavigationBar: _buildBottomTabBar(),
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      physics: _tabBarPhysics,
      controller: controller,
      children: <Widget>[
        const MapPage(),
        const TimecapsulePage(),
        const ChallengeTabPage(),
        const SettingPage(),
      ],
    );
  }

  Widget _buildBottomTabBar() {
    return Material(
      color: _backgroundColor,
      child: TabBar(
        controller: controller,
        labelColor: _primaryColor,
        unselectedLabelColor: _unselectedColor,
        indicatorColor: _primaryColor,
        tabs: const <Tab>[
          Tab(icon: Icon(_mapIcon),         text: '지도'),
          Tab(icon: Icon(_timecapsuleIcon), text: '캡슐'),
          Tab(icon: Icon(_challengeIcon), text: '업적'),
          Tab(icon: Icon(_settingsIcon),    text: '설정'),
      ],
      ),
    );
  }
}
