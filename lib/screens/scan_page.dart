// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'lobby_page.dart';

// class ScanPage extends StatefulWidget {
//   const ScanPage({super.key});
//   @override
//   State<ScanPage> createState() => _ScanPageState();
// }

// class _ScanPageState extends State<ScanPage> {
//   // ==========================================
//   // 🟢 ล็อคเป้าหมาย UUID ให้ตรงกับบอร์ด ESP32
//   // ==========================================
//   final String targetServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
//   final String targetCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

//   @override
//   void initState() {
//     super.initState();
//     // เริ่มสแกนทันทีที่เปิดหน้า
//     FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
//   }

//   void _connect(BluetoothDevice device) async {
//     // หยุดสแกนก่อนเชื่อมต่อเพื่อลดภาระเครื่อง
//     await FlutterBluePlus.stopScan();
//     try {
//       await device.connect();

//       // ค้นหา Service และ Characteristic
//       List<BluetoothService> services = await device.discoverServices();
//       BluetoothCharacteristic? targetChar;

//       // วนลูปหา Service และ Characteristic ที่ UUID ตรงกับเกมของเรา
//       for (var s in services) {
//         if (s.uuid.toString().toLowerCase() ==
//             targetServiceUuid.toLowerCase()) {
//           for (var c in s.characteristics) {
//             if (c.uuid.toString().toLowerCase() ==
//                 targetCharUuid.toLowerCase()) {
//               targetChar = c; // เจอท่อข้อมูลที่ถูกต้องแล้ว!

//               // เปิดการแจ้งเตือน (ถ้าบอร์ดรองรับ notify)
//               if (c.properties.notify) {
//                 await targetChar.setNotifyValue(true);
//               }
//               break;
//             }
//           }
//         }
//         if (targetChar != null) break;
//       }

//       if (mounted) {
//         if (targetChar != null) {
//           // ถ้าหาท่อเกมเจอ ให้ไปหน้า Lobby
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => LobbyPage(characteristic: targetChar),
//             ),
//           );
//         } else {
//           // ถ้าเชื่อมต่อได้ แต่ไม่เจอ UUID ของเกม
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text(
//                 "เชื่อมต่อสำเร็จ แต่ไม่พบ Service ของบอร์ด A-Math!",
//               ),
//               backgroundColor: Colors.red,
//             ),
//           );
//           await device.disconnect(); // ตัดการเชื่อมต่อบอร์ดที่ผิด
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("เชื่อมต่อล้มเหลว: $e")));
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("เชื่อมต่อกระดาน A-Math"),
//         backgroundColor: Colors.orange,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () =>
//                 FlutterBluePlus.startScan(timeout: const Duration(seconds: 4)),
//           ),
//         ],
//       ),
//       body: StreamBuilder<List<ScanResult>>(
//         stream: FlutterBluePlus.scanResults,
//         builder: (context, snapshot) {
//           final results = snapshot.data ?? [];
//           if (results.isEmpty) {
//             return const Center(child: Text("ไม่พบอุปกรณ์ โปรดกด Refresh"));
//           }
//           return ListView.builder(
//             itemCount: results.length,
//             itemBuilder: (context, i) {
//               final device = results[i].device;
//               return ListTile(
//                 title: Text(
//                   device.platformName.isEmpty
//                       ? "Unknown Board"
//                       : device.platformName,
//                 ),
//                 subtitle: Text(device.remoteId.toString()),
//                 trailing: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                   ),
//                   onPressed: () => _connect(device),
//                   child: const Text("Connect"),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
