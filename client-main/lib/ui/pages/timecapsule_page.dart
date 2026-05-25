import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../game/timecapsule_game.dart';

class TimecapsulePage extends StatefulWidget {
  const TimecapsulePage({super.key});

  @override
  State<TimecapsulePage> createState() => _TimecapsulePageState();
}

class _TimecapsulePageState extends State<TimecapsulePage> {
  late final TimecapsuleGame _game;

  @override
  void initState() {
    super.initState();
    _game = TimecapsuleGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          // 테스트용 버튼 (나중에 제거)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: () => _game.onCapsuleRegistered(),
                child: const Text('캡슐 보관하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}