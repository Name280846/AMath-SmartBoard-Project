// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'player_page.dart';
// import 'referee_page.dart';

// // ==========================================
// // 2. หน้า LOBBY (เพิ่มการเลือก Player 1 / 2)
// // ==========================================
// class LobbyPage extends StatefulWidget {
//   final BluetoothCharacteristic? characteristic;
//   const LobbyPage({super.key, this.characteristic});
//   @override
//   State<LobbyPage> createState() => _LobbyPageState();
// }

// class _LobbyPageState extends State<LobbyPage> {
//   String selectedRole = 'Player 1'; // ปรับให้เลือก P1 หรือ P2
//   final TextEditingController _nameController = TextEditingController();

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.blue[50],
//       appBar: AppBar(
//         title: const Text('A-MATH SERVER ROOM'),
//         centerTitle: true,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(30),
//         child: Column(
//           children: [
//             const Icon(Icons.calculate, size: 80, color: Colors.orange),
//             const SizedBox(height: 20),
//             TextField(
//               controller: _nameController,
//               decoration: InputDecoration(
//                 labelText: 'ชื่อของคุณ',
//                 filled: true,
//                 fillColor: Colors.white,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(15),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//             const Text("เลือกบทบาทในเกมนี้:"),
//             const SizedBox(height: 10),
//             Wrap(
//               spacing: 10,
//               children: [
//                 _roleBtn("Player 1", Icons.looks_one),
//                 _roleBtn("Player 2", Icons.looks_two),
//                 _roleBtn("Referee", Icons.gavel),
//               ],
//             ),
//             const SizedBox(height: 40),
//             ElevatedButton(
//               onPressed: () {
//                 if (_nameController.text.isEmpty) return;
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => selectedRole == 'Referee'
//                         ? RefereeBoardPage(
//                             adminName: _nameController.text,
//                             characteristic: widget.characteristic,
//                           )
//                         : GamePage(
//                             playerName: _nameController.text,
//                             isPlayer1:
//                                 selectedRole ==
//                                 'Player 1', // เปลี่ยนวิธีส่งค่าเป็นแบบ boolean (true/false) ตามโค้ดใหม่
//                             characteristic: widget.characteristic,
//                           ),
//                   ),
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.orangeAccent,
//                 minimumSize: const Size(double.infinity, 60),
//               ),
//               child: const Text(
//                 'เข้าสู่ห้องแข่งขัน',
//                 style: TextStyle(fontSize: 20, color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _roleBtn(String role, IconData icon) {
//     bool isSel = selectedRole == role;
//     return GestureDetector(
//       onTap: () => setState(() => selectedRole = role),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
//         decoration: BoxDecoration(
//           color: isSel ? Colors.orange : Colors.white,
//           borderRadius: BorderRadius.circular(15),
//           border: Border.all(color: Colors.orange),
//         ),
//         child: Column(
//           children: [
//             Icon(icon, color: isSel ? Colors.white : Colors.orange),
//             Text(
//               role,
//               style: TextStyle(
//                 color: isSel ? Colors.white : Colors.orange,
//                 fontSize: 12,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
