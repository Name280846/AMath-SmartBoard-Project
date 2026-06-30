// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import '../models/score_sheet_page.dart';
// import 'dart:async'; // แก้ตัวแดงที่ Timer และ StreamSubscription
// import 'dart:convert';
// import 'package:intl/intl.dart'; // แก้ตัวแดงที่ DateFormat
// // ==========================================
// // 4. หน้ากรรมการ (Referee Board Page) - ฉบับจับเวลาจริง + สีชัด
// // ==========================================

// class RefereeBoardPage extends StatefulWidget {
//   final String adminName;
//   final BluetoothCharacteristic? characteristic;

//   const RefereeBoardPage({
//     super.key,
//     required this.adminName,
//     this.characteristic,
//   });

//   @override
//   State<RefereeBoardPage> createState() => _RefereeBoardPageState();
// }

// class _RefereeBoardPageState extends State<RefereeBoardPage> {
//   // --- ตัวแปรสถานะเกม ---
//   bool p1Ready = false, p2Ready = false, gameStarted = false;
//   String lightStatus = "OFF";
//   String lastAction = "WAITING FOR PLAYERS...";
//   int currentActiveTurn = 1; // 1 = P1, 2 = P2
//   List<ScoreRecord> scoreHistory = [];
//   // --- ตัวแปรเวลา (Timer) ---
//   Timer? _gameTimer;
//   int p1Seconds = 22 * 60; // 22 นาที = 1320 วินาที
//   int p2Seconds = 22 * 60;

//   // --- ตัวแปรสำหรับ Grid และ พิกัด ---
//   Map<int, bool> scannedTiles = {};
//   int? startPoint; // จุดเริ่ม (S)
//   int? endPoint; // จุดจบ (E)

//   StreamSubscription? _btStream;

//   @override
//   void initState() {
//     super.initState();
//     _setupBluetoothListener();
//     _startGameLoop(); // เริ่มระบบ Loop เวลา
//   }

//   // ฟังก์ชันตัวนับเวลา (ทำงานทุก 1 วินาที)
//   void _startGameLoop() {
//     _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (gameStarted && lightStatus != "YELLOW") {
//         // เวลาเดินเมื่อเกมเริ่ม และไม่ใช่ช่วงกรรมการตรวจ
//         setState(() {
//           if (currentActiveTurn == 1) {
//             if (p1Seconds > 0) p1Seconds--;
//           } else {
//             if (p2Seconds > 0) p2Seconds--;
//           }
//         });
//       }
//     });
//   }

//   // ฟังก์ชันแปลงวินาทีเป็น MM:SS
//   String _formatTime(int totalSeconds) {
//     int m = totalSeconds ~/ 60;
//     int s = totalSeconds % 60;
//     return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
//   }

//   // ในไฟล์ referee_page.dart ส่วน _setupBluetoothListener
//   // ประมาณบรรทัดที่ 73
//   void _setupBluetoothListener() async {
//     // 1. เพิ่ม async ตรงนี้
//     // 2. เพิ่มบรรทัดนี้เพื่อเปิดการรับค่าจากบอร์ด
//     if (widget.characteristic != null) {
//       await widget.characteristic!.setNotifyValue(true);
//     }
//     _btStream = widget.characteristic?.lastValueStream.listen((value) {
//       if (value.isEmpty) return;
//       String msg = utf8.decode(value).trim();
//       if (msg.startsWith('{')) {
//         setState(() {
//           // จดบันทึกคะแนนลงในลิสต์ (สมุด) ไว้ลำดับแรกสุด
//           scoreHistory.insert(0, ScoreRecord.fromJson(msg));
//           lastAction = "SCORE UPDATED!";
//         });
//         return; // ✅ จดเสร็จแล้ว "จบงาน" ทันที (สำคัญมาก)
//       } // <--- นี่คือ "ผนัง

//       // แก้ไขภายใน _setupBluetoothListener ช่วง setState
//       setState(() {
//         // ใช้ contains แทน == เพื่อป้องกันกรณีมีอักขระแปลกปลอมปนมา
//         if (msg.contains("STATUS:P1_READY")) p1Ready = true;
//         if (msg.contains("STATUS:P2_READY")) p2Ready = true;
//         if (msg.contains("STATUS:ALL_READY")) {
//           p1Ready = true;
//           p2Ready = true;
//         }

//         // เพิ่มบรรทัดนี้เพื่อ Debug ดูว่าค่า p1 และ p2 เปลี่ยนจริงไหม
//         print("Current Status -> P1: $p1Ready, P2: $p2Ready");

//         // ... ส่วนที่เหลือเหมือนเดิม ...

//         if (msg == "MSG:GAME_STARTED") {
//           gameStarted = true;
//           lastAction = "GAME ON!";
//         }

//         if (msg.startsWith("LIGHT:")) lightStatus = msg.substring(6);

//         if (msg.startsWith("TURN:")) {
//           currentActiveTurn = int.parse(msg.substring(5));
//           lastAction = "TURN CHANGED: Player $currentActiveTurn";
//           scannedTiles.clear();
//           startPoint = null;
//           endPoint = null;
//         }

//         if (msg.startsWith("SCAN:")) {
//           try {
//             int idx = int.parse(msg.split('|')[1].split(':')[1]);
//             scannedTiles[idx] = true;
//           } catch (e) {
//             print("Error parsing scan: $e");
//           }
//         }

//         if (msg.startsWith("MSG:P")) {
//           lastAction = msg.substring(4).replaceAll("_", " ");
//         }
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _btStream?.cancel();
//     _gameTimer?.cancel(); // ยกเลิก Timer เมื่อออกจากหน้า
//     super.dispose();
//   }

//   // 📊 ฟังก์ชันสำหรับสร้างหน้าต่างเด้งขึ้นมาโชว์คะแนน
//   void _showScoreHistory() {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Row(
//             children: [
//               Icon(Icons.history, color: Colors.blue),
//               SizedBox(width: 10),
//               Text("ประวัติคะแนนย้อนหลัง"),
//             ],
//           ),
//           content: SizedBox(
//             width: double.maxFinite,
//             height: 300,
//             child: scoreHistory.isEmpty
//                 ? const Center(child: Text("ยังไม่มีคะแนนบันทึก"))
//                 : ListView.builder(
//                     itemCount: scoreHistory.length,
//                     itemBuilder: (context, index) {
//                       final record = scoreHistory[index];
//                       return Card(
//                         child: ListTile(
//                           leading: CircleAvatar(
//                             child: Text("${scoreHistory.length - index}"),
//                           ),
//                           title: Text(
//                             "P1: ${record.p1Score} | P2: ${record.p2Score}",
//                           ),
//                           subtitle: Text("เวลา: ${record.timestamp}"),
//                         ), // ListTile
//                       ); // Card
//                     }, // itemBuilder
//                   ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("ปิด"),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _sendAction(String act) async {
//     if (widget.characteristic != null) {
//       await widget.characteristic!.write(utf8.encode(act));
//     }
//   }

//   void _approveWithCoordinates() {
//     if (startPoint == null || endPoint == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("กรุณาเลือกจุดเริ่ม (S) และจุดจบ (E) ก่อน"),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
//     _sendAction("REF:APPROVE|S:$startPoint|E:$endPoint");
//     setState(() {
//       startPoint = null;
//       endPoint = null;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F5F5),
//       appBar: AppBar(
//         title: Text("Referee: ${widget.adminName}"),
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.black,
//         elevation: 2,
//         actions: [
//           // 🏆 1. เพิ่มปุ่มไอคอนรูปตารางคะแนนตรงนี้
//           IconButton(
//             icon: const Icon(Icons.leaderboard, color: Colors.blueAccent),
//             onPressed: () {
//               _showScoreHistory(); // สั่งให้หน้าต่างคะแนนเด้งขึ้นมา
//             },
//           ),
//           // แสดงเวลากลางบน AppBar ด้วยก็ได้
//           Center(
//             child: Padding(
//               padding: const EdgeInsets.only(right: 20),
//               child: Text(
//                 gameStarted ? "TIME ON" : "PAUSED",
//                 style: TextStyle(color: Colors.grey, fontSize: 12),
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           _build3LEDStatus(), // แสดงไฟ + เวลา
//           _buildLogBox(),
//           Expanded(child: _buildGridBoard()),
//           _buildBottomButtons(),
//         ],
//       ),
//     );
//   }

//   // --- WIDGETS ---

//   // 1. ส่วนแสดงไฟ LED + เวลา (แก้ไขใหม่)
//   Widget _build3LEDStatus() {
//     bool isRefTurn = (lightStatus == "YELLOW");

//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 10),
//       color: Colors.white,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: [
//           _ledLamp("REFEREE", isRefTurn ? Colors.green : Colors.yellow, null),
//           // เพิ่มเวลาเข้าไปในช่อง Player
//           _ledLamp(
//             "PLAYER 1",
//             (gameStarted && currentActiveTurn == 1 && !isRefTurn)
//                 ? Colors.green
//                 : Colors.yellow,
//             p1Seconds,
//           ),
//           _ledLamp(
//             "PLAYER 2",
//             (gameStarted && currentActiveTurn == 2 && !isRefTurn)
//                 ? Colors.green
//                 : Colors.yellow,
//             p2Seconds,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _ledLamp(String label, Color color, int? timeLeft) {
//     return Column(
//       children: [
//         Container(
//           width: 35,
//           height: 35, // ขยายไฟนิดนึง
//           decoration: BoxDecoration(
//             color: color,
//             shape: BoxShape.circle,
//             border: Border.all(color: Colors.black12, width: 2),
//             boxShadow: [
//               BoxShadow(
//                 color: color.withOpacity(0.6),
//                 blurRadius: 8,
//                 spreadRadius: 1,
//               ),
//             ],
//           ),
//           child: Center(
//             child: timeLeft != null
//                 ? Icon(
//                     Icons.timer,
//                     size: 20,
//                     color: Colors.black38,
//                   ) // ไอคอนนาฬิกาจางๆ
//                 : Icon(
//                     Icons.gavel,
//                     size: 20,
//                     color: Colors.black38,
//                   ), // ไอคอนกรรมการ
//           ),
//         ),
//         const SizedBox(height: 5),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
//         ),

//         // ส่วนแสดงตัวเลขเวลา
//         if (timeLeft != null)
//           Container(
//             margin: const EdgeInsets.only(top: 2),
//             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//             decoration: BoxDecoration(
//               color: Colors.black87,
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: Text(
//               _formatTime(timeLeft),
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.bold,
//                 fontFamily: 'monospace',
//               ),
//             ),
//           )
//         else
//           const SizedBox(height: 18), // เว้นที่ให้เท่ากัน
//       ],
//     );
//   }

//   // 2. กล่องข้อความ Log
//   Widget _buildLogBox() {
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.all(5),
//       padding: const EdgeInsets.all(8),
//       color: Colors.amber[50],
//       child: Text(
//         "STATUS: $lastAction",
//         textAlign: TextAlign.center,
//         style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold),
//       ),
//     );
//   }

//   // 3. ตาราง Grid 15x15 (แก้สี S/E ตรงนี้)
//   Widget _buildGridBoard() {
//     return Padding(
//       padding: const EdgeInsets.all(4.0),
//       child: AspectRatio(
//         aspectRatio: 1,
//         child: GridView.builder(
//           physics: const NeverScrollableScrollPhysics(),
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 15,
//           ),
//           itemCount: 225,
//           itemBuilder: (context, index) {
//             int r = index ~/ 15;
//             int c = index % 15;

//             Color boxColor = _getBoardColor(r, c);
//             String text = _getBoardText(r, c);
//             Color textColor = Colors.black54;
//             FontWeight fontWeight = FontWeight.normal;

//             // --- แก้สีจุด S และ E ให้เด่นชัด ---
//             if (index == startPoint) {
//               boxColor = Colors.purple[700]!; // สีม่วงเข้ม
//               text = "S";
//               textColor = Colors.white;
//               fontWeight = FontWeight.w900;
//             } else if (index == endPoint) {
//               boxColor = Colors.black; // สีดำ
//               text = "E";
//               textColor = Colors.white;
//               fontWeight = FontWeight.w900;
//             } else if (scannedTiles.containsKey(index)) {
//               boxColor = Colors.green[800]!;
//               text = "✔";
//               textColor = Colors.white;
//             }

//             return GestureDetector(
//               onTap: () {
//                 setState(() {
//                   if (startPoint == null) {
//                     startPoint = index;
//                   } else if (endPoint == null) {
//                     endPoint = index;
//                   } else {
//                     startPoint = index;
//                     endPoint = null;
//                   }
//                 });
//               },
//               child: Container(
//                 margin: const EdgeInsets.all(0.5),
//                 color: boxColor,
//                 child: Center(
//                   child: Text(
//                     text,
//                     style: TextStyle(
//                       fontSize: (text == "S" || text == "E")
//                           ? 10
//                           : 6, // ขยายตัว S, E
//                       color: textColor,
//                       fontWeight: fontWeight,
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   // 4. ปุ่มกดด้านล่าง
//   Widget _buildBottomButtons() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
//       child: !gameStarted
//           ? ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//                 minimumSize: const Size.fromHeight(50),
//               ),
//               onPressed: (p1Ready && p2Ready)
//                   ? () => _sendAction("REF:START")
//                   : null,
//               child: const Text(
//                 "START GAME (22 Mins)",
//                 style: TextStyle(color: Colors.white, fontSize: 18),
//               ),
//             )
//           : lightStatus == "YELLOW"
//           ? Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     onPressed: () => _sendAction("REF:REJECT"),
//                     child: const Text("REJECT"),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green,
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     onPressed: _approveWithCoordinates,
//                     child: const Text("APPROVE (Send)"),
//                   ),
//                 ),
//               ],
//             )
//           : Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: Colors.grey[200],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Center(
//                 child: Text(
//                   "Waiting for Player ${currentActiveTurn}...",
//                   style: const TextStyle(color: Colors.grey),
//                 ),
//               ),
//             ),
//     );
//   }

//   Color _getBoardColor(int r, int c) {
//     if ((r == 0 || r == 7 || r == 14) && (c == 0 || c == 7 || c == 14))
//       return (r == 7 && c == 7)
//           ? const Color(0xFF38BDF8)
//           : const Color(0xFFEF4444);
//     List<List<int>> yel = [
//       [1, 1],
//       [2, 2],
//       [3, 3],
//       [4, 4],
//       [1, 13],
//       [2, 12],
//       [3, 11],
//       [4, 10],
//       [13, 1],
//       [12, 2],
//       [11, 3],
//       [10, 4],
//       [13, 13],
//       [12, 12],
//       [11, 11],
//       [10, 10],
//     ];
//     for (var p in yel)
//       if (p[0] == r && p[1] == c) return const Color(0xFFFDE047);
//     List<List<int>> blu = [
//       [1, 5],
//       [1, 9],
//       [5, 1],
//       [5, 5],
//       [5, 9],
//       [5, 13],
//       [9, 1],
//       [9, 5],
//       [9, 9],
//       [9, 13],
//       [13, 5],
//       [13, 9],
//       [4, 4],
//       [4, 10],
//       [10, 10],
//       [10, 4],
//     ];
//     for (var p in blu)
//       if (p[0] == r && p[1] == c) return const Color(0xFF38BDF8);
//     List<List<int>> ora = [
//       [0, 3],
//       [0, 11],
//       [2, 6],
//       [2, 8],
//       [3, 0],
//       [3, 7],
//       [3, 14],
//       [6, 2],
//       [6, 6],
//       [6, 8],
//       [6, 12],
//       [7, 3],
//       [7, 11],
//       [8, 2],
//       [8, 6],
//       [8, 8],
//       [8, 12],
//       [11, 0],
//       [11, 7],
//       [11, 14],
//       [12, 6],
//       [12, 8],
//       [14, 3],
//       [14, 11],
//     ];
//     for (var p in ora)
//       if (p[0] == r && p[1] == c) return const Color(0xFFFB923C);
//     return const Color(0xFFD1FAE5);
//   }

//   String _getBoardText(int r, int c) {
//     if (r == 7 && c == 7) return "★";
//     Color col = _getBoardColor(r, c);
//     if (col == const Color(0xFFEF4444)) return "3W";
//     if (col == const Color(0xFFFDE047)) return "2W";
//     if (col == const Color(0xFF38BDF8)) return "3L";
//     if (col == const Color(0xFFFB923C)) return "2L";
//     return "";
//   }
// }

// class ScoreRecord {
//   final int p1Score;
//   final int p2Score;
//   final String timestamp;

//   ScoreRecord({
//     required this.p1Score,
//     required this.p2Score,
//     required this.timestamp,
//   });

//   // ฟังก์ชันสำหรับแปลงข้อความ JSON จาก Bluetooth มาเป็น Object ในแอป
//   factory ScoreRecord.fromJson(String jsonStr) {
//     final data = json.decode(jsonStr);
//     return ScoreRecord(
//       p1Score: data['p1'] ?? 0,
//       p2Score: data['p2'] ?? 0,
//       timestamp: DateFormat('HH:mm:ss').format(DateTime.now()),
//     );
//   }
// }
