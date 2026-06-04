import 'package:flutter/material.dart';
import 'ui/game_screen.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameScreen(),
    ),
  );
}