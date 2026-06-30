// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import '../models/score_sheet_page.dart';
// import 'dart:async'; // แก้ตัวแดงที่ Timer และ StreamSubscription
// import '../models/score_sheet_page.dart'; // แก้ตัวแดงที่ ScoreSheetPage (ถ้ามีการเรียกใช้)
// import 'dart:convert';

// // ==========================================
// // 3. หน้าเล่นเกม (GamePage) - UI ใหม่ (Dark Slate + LED Style)
// // ==========================================

// class GamePage extends StatefulWidget {
//   final String playerName;
//   final bool isPlayer1; // ใช้เช็คว่าเป็น P1 หรือ P2
//   final BluetoothCharacteristic? characteristic;

//   const GamePage({
//     super.key,
//     required this.playerName,
//     required this.isPlayer1,
//     this.characteristic,
//   });

//   @override
//   State<GamePage> createState() => _GamePageState();
// }

// class _GamePageState extends State<GamePage> {
//   // --- ตัวแปรสถานะเกม ---
//   bool gameStarted = false; // เกมเริ่มหรือยัง
//   bool iAmReady = false; // เรากด Ready หรือยัง
//   String lightStatus = "OFF";
//   int currentTurn = 1; // 1 หรือ 2

//   // --- ตัวแปรเวลา ---
//   Timer? _gameTimer;
//   int p1Seconds = 22 * 60; // 22 นาที
//   int p2Seconds = 22 * 60;

//   StreamSubscription? _btStream;

//   @override
//   void initState() {
//     super.initState();
//     _setupBluetoothListener();
//     _startGameLoop();
//   }

//   // ฟังก์ชันลูปเวลา (ทำงานทุก 1 วินาที)
//   void _startGameLoop() {
//     _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (gameStarted && lightStatus != "YELLOW") {
//         setState(() {
//           if (currentTurn == 1) {
//             if (p1Seconds > 0) p1Seconds--;
//           } else {
//             if (p2Seconds > 0) p2Seconds--;
//           }
//         });
//       }
//     });
//   }

//   String _formatTime(int totalSeconds) {
//     int m = totalSeconds ~/ 60;
//     int s = totalSeconds % 60;
//     return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
//   }

//   void _setupBluetoothListener() async {
//     // 1. เพิ่ม async ตรงนี้

//     // 2. เพิ่มบรรทัดนี้เพื่อเปิดการรับค่า (Notify) จาก ESP32
//     if (widget.characteristic != null) {
//       await widget.characteristic!.setNotifyValue(true);
//     }
//     _btStream = widget.characteristic?.lastValueStream.listen((value) {
//       if (value.isEmpty) return;
//       String msg = utf8.decode(value).trim();

//       setState(() {
//         if (msg == "MSG:GAME_STARTED") {
//           gameStarted = true;
//         }

//         if (msg.startsWith("LIGHT:")) {
//           lightStatus = msg.substring(6); // YELLOW, GREEN, RED, OFF
//         }

//         if (msg.startsWith("TURN:")) {
//           currentTurn = int.parse(msg.substring(5));
//         }
//       });
//     });
//   }

//   void _sendAction(String act) async {
//     if (widget.characteristic != null) {
//       // ส่งคำสั่งตามรูปแบบที่ ESP32 เข้าใจ (CMD:...)
//       String command = act == "READY"
//           ? "CMD:READY"
//           : "CMD:${act.toUpperCase()}";
//       await widget.characteristic!.write(utf8.encode(command));
//     }
//   }

//   @override
//   void dispose() {
//     _btStream?.cancel();
//     _gameTimer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // คำนวณสถานะต่างๆ
//     bool isMyTurn =
//         (widget.isPlayer1 && currentTurn == 1) ||
//         (!widget.isPlayer1 && currentTurn == 2);
//     bool isRefChecking = (lightStatus == "YELLOW");
//     bool controlsActive = isMyTurn && !isRefChecking && gameStarted;

//     // เวลาที่จะแสดง (แสดงเวลาของเรา)
//     int myTime = widget.isPlayer1 ? p1Seconds : p2Seconds;

//     // --- 1. หน้า Lobby (ก่อนเริ่มเกม) ---
//     if (!gameStarted) {
//       return Scaffold(
//         backgroundColor: const Color(0xFF020617), // Dark Slate
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 widget.playerName.toUpperCase(),
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 30,
//                   fontWeight: FontWeight.bold,
//                   letterSpacing: 2,
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Text(
//                 widget.isPlayer1 ? "PLAYER 1" : "PLAYER 2",
//                 style: const TextStyle(
//                   color: Colors.orange,
//                   fontSize: 18,
//                   letterSpacing: 1.5,
//                 ),
//               ),
//               const SizedBox(height: 60),
//               iAmReady
//                   ? Column(
//                       children: const [
//                         CircularProgressIndicator(color: Colors.orange),
//                         SizedBox(height: 30),
//                         Text(
//                           "WAITING FOR OPPONENT...",
//                           style: TextStyle(
//                             color: Colors.white54,
//                             fontSize: 16,
//                             letterSpacing: 1,
//                           ),
//                         ),
//                       ],
//                     )
//                   : SizedBox(
//                       width: 250,
//                       height: 60,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.green[600],
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(30),
//                           ),
//                           elevation: 10,
//                           shadowColor: Colors.greenAccent.withOpacity(0.5),
//                         ),
//                         onPressed: () {
//                           setState(() => iAmReady = true);
//                           _sendAction("READY");
//                         },
//                         child: const Text(
//                           "I'M READY",
//                           style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ),
//             ],
//           ),
//         ),
//       );
//     }

//     // --- 2. หน้าเล่นเกม (UI ใหม่) ---
//     return Scaffold(
//       backgroundColor: const Color(0xFF020617), // Dark Slate Background
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 20.0),
//           child: Column(
//             children: [
//               const SizedBox(height: 30),

//               // กล่องเวลา (ตรงกลาง)
//               _timerUI(myTime, isMyTurn, isRefChecking),

//               const SizedBox(height: 40),

//               // ไฟสถานะ Referee (Check)
//               _refereeLED(isRefChecking),

//               const Spacer(),

//               // ไฟสถานะผู้เล่น (Turn Indicators)
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _playerLED(
//                     "YOU",
//                     widget.isPlayer1 ? Colors.greenAccent : Colors.blueAccent,
//                     isMyTurn, // ไฟติดถ้าเป็นตาเรา
//                   ),
//                   _playerLED(
//                     "OPPONENT",
//                     Colors.redAccent,
//                     !isMyTurn, // ไฟติดถ้าเป็นตาเขา
//                   ),
//                 ],
//               ),

//               const Spacer(),

//               // ปุ่มควบคุม (Pass / Change / Submit)
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 30),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: _btn(
//                         "PASS",
//                         controlsActive,
//                         color: Colors.grey[800]!,
//                       ),
//                     ),
//                     const SizedBox(width: 15),
//                     Expanded(
//                       child: _btn(
//                         "CHANGE",
//                         controlsActive,
//                         color: Colors.grey[800]!,
//                       ),
//                     ),
//                     const SizedBox(width: 15),
//                     Expanded(
//                       child: _btn("SUBMIT", controlsActive, isHighlight: true),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // --- Widget 1: Timer ตรงกลาง ---
//   Widget _timerUI(int seconds, bool isMyTurn, bool isRefChecking) {
//     Color glowColor = isRefChecking
//         ? Colors.yellow
//         : (isMyTurn ? Colors.greenAccent : Colors.white10);

//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(vertical: 30),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0F172A), // Lighter Slate
//         borderRadius: BorderRadius.circular(25),
//         border: Border.all(color: glowColor.withOpacity(0.5), width: 2),
//         boxShadow: isMyTurn || isRefChecking
//             ? [
//                 BoxShadow(
//                   color: glowColor.withOpacity(0.15),
//                   blurRadius: 20,
//                   spreadRadius: 2,
//                 ),
//               ]
//             : [],
//       ),
//       child: Column(
//         children: [
//           Text(
//             _formatTime(seconds),
//             style: TextStyle(
//               color: isMyTurn ? Colors.white : Colors.white38,
//               fontSize: 70,
//               fontWeight: FontWeight.bold,
//               fontFamily: 'monospace', // ให้ตัวเลขดูเป็นดิจิทัล
//               letterSpacing: -2,
//             ),
//           ),
//           const SizedBox(height: 10),
//           Text(
//             isRefChecking
//                 ? "REFEREE CHECKING..."
//                 : (isMyTurn ? "• YOUR TURN •" : "OPPONENT'S TURN"),
//             style: TextStyle(
//               color: isRefChecking
//                   ? Colors.yellow
//                   : (isMyTurn ? Colors.greenAccent : Colors.white24),
//               fontSize: 14,
//               letterSpacing: 2,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // --- Widget 2: ไฟ Referee ---
//   Widget _refereeLED(bool active) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//     decoration: BoxDecoration(
//       color: active ? Colors.yellow.withOpacity(0.1) : Colors.transparent,
//       borderRadius: BorderRadius.circular(20),
//     ),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         AnimatedContainer(
//           duration: const Duration(milliseconds: 300),
//           width: 12,
//           height: 12,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: active ? Colors.yellow : Colors.grey[800],
//             boxShadow: active
//                 ? [
//                     const BoxShadow(
//                       color: Colors.yellow,
//                       blurRadius: 15,
//                       spreadRadius: 2,
//                     ),
//                   ]
//                 : [],
//           ),
//         ),
//         const SizedBox(width: 15),
//         Text(
//           "REFEREE STATUS",
//           style: TextStyle(
//             color: active ? Colors.yellow : Colors.grey[700],
//             fontWeight: FontWeight.bold,
//             fontSize: 14,
//             letterSpacing: 1,
//           ),
//         ),
//       ],
//     ),
//   );

//   // --- Widget 3: ไฟผู้เล่น (Turn Indicator) ---
//   Widget _playerLED(String name, Color col, bool active) => Column(
//     children: [
//       AnimatedContainer(
//         duration: const Duration(milliseconds: 300),
//         width: 60,
//         height: 60,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: const Color(0xFF0F172A),
//           border: Border.all(
//             color: active ? col : Colors.transparent,
//             width: 2,
//           ),
//           boxShadow: active
//               ? [BoxShadow(color: col.withOpacity(0.4), blurRadius: 20)]
//               : [],
//         ),
//         child: Icon(
//           Icons.person,
//           color: active ? col : Colors.grey[800],
//           size: 30,
//         ),
//       ),
//       const SizedBox(height: 12),
//       Text(
//         name,
//         style: TextStyle(
//           color: active ? Colors.white : Colors.grey[700],
//           fontSize: 12,
//           fontWeight: FontWeight.bold,
//           letterSpacing: 1,
//         ),
//       ),
//     ],
//   );

//   // --- Widget 4: ปุ่มกด ---
//   Widget _btn(
//     String label,
//     bool active, {
//     Color? color,
//     bool isHighlight = false,
//   }) => SizedBox(
//     height: 65,
//     child: ElevatedButton(
//       onPressed: active ? () => _sendAction(label) : null,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: isHighlight
//             ? Colors.orange[700]
//             : (color ?? Colors.grey[900]),
//         foregroundColor: Colors.white,
//         disabledBackgroundColor: const Color(
//           0xFF1E293B,
//         ), // สีเทาเข้มมากตอนกดไม่ได้
//         disabledForegroundColor: Colors.grey[700],
//         elevation: active ? 5 : 0,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         padding: EdgeInsets.zero, // ให้จัด layout เอง
//       ),
//       child: Text(
//         label,
//         style: TextStyle(
//           fontSize: 14,
//           fontWeight: FontWeight.bold,
//           letterSpacing: 1,
//           color: active ? Colors.white : Colors.grey[600],
//         ),
//       ),
//     ),
//   );
// }
