import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(
    const MaterialApp(
      home: ScanPage(),
      debugShowCheckedModeBanner: false,
      title: "A-Math Smart Board",
    ),
  );
}

// ==========================================
// 1. หน้า SCAN
// ==========================================
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  @override
  void initState() {
    super.initState();
    // 2. เปลี่ยนจากการสั่ง Scan ทันที เป็นเรียกฟังก์ชันขอสิทธิ์ก่อน
    _checkPermissionsAndStartScan();
  }

  // 3. เพิ่มฟังก์ชันขอสิทธิ์ตรงนี้
  Future<void> _checkPermissionsAndStartScan() async {
    // ขอสิทธิ์ Location และ Bluetooth พร้อมกัน
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // ตรวจสอบว่าผู้ใช้กด "อนุญาต" ครบไหม
    if (statuses[Permission.location]!.isGranted &&
        statuses[Permission.bluetoothScan]!.isGranted) {
      // ถ้าอนุญาตแล้ว ถึงจะสั่งให้เริ่มสแกนหาบอร์ด ESP32
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    } else {
      // ถ้าผู้ใช้กดไม่อนุญาต ให้แจ้งเตือนผ่าน SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "กรุณาเปิด GPS และอนุญาตสิทธิ์ Location เพื่อสแกนหาบอร์ด",
            ),
            backgroundColor: Colors.red,
          ),
        );
        // สามารถใช้คำสั่ง openAppSettings(); เพื่อบังคับเด้งไปหน้าตั้งค่ามือถือได้
      }
    }
  }

  void _connect(BluetoothDevice device) async {
    // ... (ส่วนโค้ด _connect ของคุณคงเดิม ไม่ต้องแก้ครับ)
    await FlutterBluePlus.stopScan();
    try {
      await device.connect();
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write || c.properties.notify) {
            targetChar = c;
            await targetChar.setNotifyValue(true);
            break;
          }
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LobbyPage(characteristic: targetChar),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (ส่วนโค้ด build ของคุณคงเดิม ไม่ต้องแก้ครับ)
    return Scaffold(
      appBar: AppBar(
        title: const Text("เชื่อมต่อกระดาน A-Math"),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<List<ScanResult>>(
        stream: FlutterBluePlus.scanResults,
        builder: (context, snapshot) {
          final results = snapshot.data ?? [];
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(
                results[i].device.platformName.isEmpty
                    ? "Unknown Board"
                    : results[i].device.platformName,
              ),
              subtitle: Text(results[i].device.remoteId.toString()),
              trailing: ElevatedButton(
                onPressed: () => _connect(results[i].device),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Connect"),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 2. หน้า LOBBY (เพิ่มการเลือก Player 1 / 2)
// ==========================================
class LobbyPage extends StatefulWidget {
  final BluetoothCharacteristic? characteristic;
  const LobbyPage({super.key, this.characteristic});
  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  String selectedRole = 'Player 1'; // ปรับให้เลือก P1 หรือ P2
  final TextEditingController _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text('A-MATH SERVER ROOM'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(Icons.calculate, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'ชื่อของคุณ',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("เลือกบทบาทในเกมนี้:"),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                _roleBtn("Player 1", Icons.looks_one),
                _roleBtn("Player 2", Icons.looks_two),
                _roleBtn("Referee", Icons.gavel),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => selectedRole == 'Referee'
                        ? RefereeBoardPage(
                            adminName: _nameController.text,
                            characteristic: widget.characteristic,
                          )
                        : GamePage(
                            playerName: _nameController.text,
                            isPlayer1:
                                selectedRole ==
                                'Player 1', // เปลี่ยนวิธีส่งค่าเป็นแบบ boolean (true/false) ตามโค้ดใหม่
                            characteristic: widget.characteristic,
                          ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                minimumSize: const Size(double.infinity, 60),
              ),
              child: const Text(
                'เข้าสู่ห้องแข่งขัน',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleBtn(String role, IconData icon) {
    bool isSel = selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => selectedRole = role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSel ? Colors.white : Colors.orange),
            Text(
              role,
              style: TextStyle(
                color: isSel ? Colors.white : Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. หน้าเล่นเกม (GamePage) - UI ใหม่ (Dark Slate + LED Style) แนวนอน + ระบบจบเกม
// ==========================================

class GamePage extends StatefulWidget {
  final String playerName;
  final bool isPlayer1; // ใช้เช็คว่าเป็น P1 หรือ P2
  final BluetoothCharacteristic? characteristic;

  const GamePage({
    super.key,
    required this.playerName,
    required this.isPlayer1,
    this.characteristic,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  // --- ตัวแปรสถานะเกม ---
  bool gameStarted = false; // เกมเริ่มหรือยัง
  bool iAmReady = false; // เรากด Ready หรือยัง
  String lightStatus = "OFF";
  int currentTurn = 1; // 1 หรือ 2

  // --- ตัวแปรคะแนน ---
  int p1Score = 0;
  int p2Score = 0;

  // --- ตัวแปรเวลา ---
  Timer? _gameTimer;
  int p1Seconds = 22 * 60; // 22 นาที
  int p2Seconds = 22 * 60;

  StreamSubscription? _btStream;

  @override
  void initState() {
    super.initState();

    // บังคับล็อกหน้าจอเป็น "แนวนอน" เมื่อเข้ามาหน้านี้
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    // เปิดการรอรับค่า Bluetooth และเริ่มลูปเวลา
    _setupBluetoothListener();
    _startGameLoop();
  }

  // ฟังก์ชันลูปเวลา (ทำงานทุก 1 วินาที)
  void _startGameLoop() {
    _gameTimer?.cancel(); // กันลูปซ้อน (เวลาเดินเบิ้ล)
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (gameStarted && lightStatus != "YELLOW") {
        setState(() {
          if (currentTurn == 1) {
            if (p1Seconds > 0) p1Seconds--;
          } else {
            if (p2Seconds > 0) p2Seconds--;
          }
        });
      }
    });
  }

  // ฟังก์ชันแปลงวินาทีเป็นรูปแบบ MM:SS
  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // ฟังก์ชันรับค่าจาก ESP32
  void _setupBluetoothListener() {
    _btStream = widget.characteristic?.lastValueStream.listen((value) {
      if (value.isEmpty) return;
      String msg = utf8.decode(value).trim();

      setState(() {
        if (msg == "MSG:GAME_STARTED") {
          gameStarted = true;
        }

        if (msg.startsWith("LIGHT:")) {
          lightStatus = msg.substring(6); // YELLOW, GREEN, RED, OFF
        }

        if (msg.startsWith("TURN:")) {
          currentTurn = int.parse(msg.substring(5));
        }

        if (msg.startsWith("SCORE:")) {
          List<String> parts = msg.split(":");
          if (parts.length >= 3) {
            int playerNum = int.tryParse(parts[1]) ?? 1;
            int totalScore = int.tryParse(parts[2]) ?? 0;
            if (playerNum == 1) p1Score = totalScore;
            if (playerNum == 2) p2Score = totalScore;
          }
        }

        // ดักจับคำสั่งจบเกมจากบอร์ด ESP32
        if (msg.startsWith("GAME_OVER") || msg == "MSG:GAME_OVER") {
          _gameTimer?.cancel(); // หยุดเวลาทันที
          _showGameOverDialog(); // เรียกหน้าต่างสรุปผลขึ้นมา
        }
      });
    });
  }

  // ฟังก์ชันส่งคำสั่งไปยัง ESP32
  void _sendAction(String act) async {
    if (widget.characteristic != null) {
      String command = act == "READY"
          ? "CMD:READY"
          : "CMD:${act.toUpperCase()}";
      await widget.characteristic!.write(utf8.encode(command));
    }
  }

  // ฟังก์ชันแสดงหน้าต่างจบเกม สำหรับฝั่งผู้เล่น
  void _showGameOverDialog() {
    String resultText = "DRAW!";
    Color resultColor = Colors.orange;

    if (p1Score > p2Score) {
      resultText = widget.isPlayer1 ? "YOU WIN! 🎉" : "OPPONENT WINS";
      resultColor = widget.isPlayer1 ? Colors.greenAccent : Colors.redAccent;
    } else if (p2Score > p1Score) {
      resultText = widget.isPlayer1 ? "OPPONENT WINS" : "YOU WIN! 🎉";
      resultColor = widget.isPlayer1 ? Colors.redAccent : Colors.greenAccent;
    }

    showDialog(
      context: context,
      barrierDismissible:
          false, // บังคับให้กดปุ่มเท่านั้น ห้ามกดที่ว่างเพื่อปิด
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          // 🌟 ลดพื้นที่ว่างด้านบนและล่างของเนื้อหาใน Dialog เพื่อให้พอดีจอแนวนอน
          contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
          title: const Center(
            child: Text(
              "GAME OVER",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20, // 🌟 ลดจาก 24 เหลือ 20
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                resultText,
                style: TextStyle(
                  color: resultColor,
                  fontSize: 22, // 🌟 ลดจาก 28 เหลือ 22
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10), // 🌟 ลดช่องว่างจาก 20 เหลือ 10
              Container(
                padding: const EdgeInsets.all(10), // 🌟 ลดขอบในจาก 15 เหลือ 10
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          "YOUR SCORE",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ), // 🌟 ลดจาก 12
                        ),
                        Text(
                          "${widget.isPlayer1 ? p1Score : p2Score}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20, // 🌟 ลดจาก 24 เหลือ 20
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          "OPPONENT",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ), // 🌟 ลดจาก 12
                        ),
                        Text(
                          "${widget.isPlayer1 ? p2Score : p1Score}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20, // 🌟 ลดจาก 24 เหลือ 20
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10, // 🌟 ลดจาก 12 เหลือ 10
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // ปิด Dialog
                  Navigator.pop(context); // เด้งกลับไปหน้า Lobby
                },
                child: const Text(
                  "EXIT TO LOBBY",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _btStream?.cancel();
    _gameTimer?.cancel();

    // คืนค่าให้หน้าจอหมุนได้ปกติ หรือกลับเป็นแนวตั้งเมื่อออกจากหน้านี้
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณสถานะต่างๆ
    bool isMyTurn =
        (widget.isPlayer1 && currentTurn == 1) ||
        (!widget.isPlayer1 && currentTurn == 2);
    bool isRefChecking = (lightStatus == "YELLOW");
    bool controlsActive = isMyTurn && !isRefChecking && gameStarted;

    // เวลาที่จะแสดง (แสดงเวลาของเรา)
    int myTime = widget.isPlayer1 ? p1Seconds : p2Seconds;

    // --- 1. หน้า Lobby (ก่อนเริ่มเกม) ---
    if (!gameStarted) {
      return Scaffold(
        backgroundColor: const Color(0xFF020617), // Dark Slate
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.playerName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.isPlayer1 ? "PLAYER 1" : "PLAYER 2",
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              iAmReady
                  ? const Column(
                      children: [
                        CircularProgressIndicator(color: Colors.orange),
                        SizedBox(height: 20),
                        Text(
                          "WAITING FOR OPPONENT...",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: 250,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 10,
                          shadowColor: Colors.greenAccent.withOpacity(0.5),
                        ),
                        onPressed: () {
                          setState(() => iAmReady = true);
                          _sendAction("READY");
                        },
                        child: const Text(
                          "I'M READY",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      );
    }

    // --- 2. หน้าเล่นเกม (UI แนวนอน แบ่งซ้าย-ขวา) ---
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Dark Slate Background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // --- ฝั่งซ้าย (สัดส่วน 40%): กล่องเวลา + สถานะกรรมการ ---
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _timerUI(myTime, isMyTurn, isRefChecking),
                    const SizedBox(height: 20),
                    _refereeLED(isRefChecking),
                  ],
                ),
              ),

              const SizedBox(width: 30), // ระยะห่างตรงกลาง
              // --- ฝั่งขวา (สัดส่วน 60%): ผู้เล่น และ ปุ่มกด ---
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ไฟสถานะผู้เล่น
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _playerLED(
                          "YOU",
                          widget.isPlayer1
                              ? Colors.greenAccent
                              : Colors.blueAccent,
                          isMyTurn,
                          widget.isPlayer1 ? p1Score : p2Score,
                        ),
                        _playerLED(
                          "OPPONENT",
                          Colors.redAccent,
                          !isMyTurn,
                          widget.isPlayer1 ? p2Score : p1Score,
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // ปุ่มควบคุม (Pass / Change / Submit)
                    Row(
                      children: [
                        Expanded(
                          child: _btn(
                            "PASS",
                            controlsActive,
                            color: Colors.grey[800]!,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _btn(
                            "CHANGE",
                            controlsActive,
                            color: Colors.grey[800]!,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _btn(
                            "SUBMIT",
                            controlsActive,
                            isHighlight: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget 1: Timer ---
  Widget _timerUI(int seconds, bool isMyTurn, bool isRefChecking) {
    Color glowColor = isRefChecking
        ? Colors.yellow
        : (isMyTurn ? Colors.greenAccent : Colors.white10);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: glowColor.withOpacity(0.5), width: 2),
        boxShadow: isMyTurn || isRefChecking
            ? [
                BoxShadow(
                  color: glowColor.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          Text(
            _formatTime(seconds),
            style: TextStyle(
              color: isMyTurn ? Colors.white : Colors.white38,
              fontSize: 60,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isRefChecking
                ? "REFEREE CHECKING..."
                : (isMyTurn ? "• YOUR TURN •" : "OPPONENT'S TURN"),
            style: TextStyle(
              color: isRefChecking
                  ? Colors.yellow
                  : (isMyTurn ? Colors.greenAccent : Colors.white24),
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget 2: ไฟ Referee ---
  Widget _refereeLED(bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: BoxDecoration(
      color: active ? Colors.yellow.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.yellow : Colors.grey[800],
            boxShadow: active
                ? [
                    const BoxShadow(
                      color: Colors.yellow,
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(width: 15),
        Text(
          "REFEREE STATUS",
          style: TextStyle(
            color: active ? Colors.yellow : Colors.grey[700],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );

  // --- Widget 3: ไฟผู้เล่น (Turn Indicator) ---
  Widget _playerLED(String name, Color col, bool active, int score) => Column(
    children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0F172A),
          border: Border.all(
            color: active ? col : Colors.transparent,
            width: 2,
          ),
          boxShadow: active
              ? [BoxShadow(color: col.withOpacity(0.4), blurRadius: 20)]
              : [],
        ),
        child: Icon(
          Icons.person,
          color: active ? col : Colors.grey[800],
          size: 25,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        name,
        style: TextStyle(
          color: active ? Colors.white : Colors.grey[700],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        "$score",
        style: TextStyle(
          color: active ? col : Colors.grey[600],
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    ],
  );

  // --- Widget 4: ปุ่มกด ---
  Widget _btn(
    String label,
    bool active, {
    Color? color,
    bool isHighlight = false,
  }) => SizedBox(
    height: 60,
    child: ElevatedButton(
      onPressed: active ? () => _sendAction(label) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isHighlight
            ? Colors.orange[700]
            : (color ?? Colors.grey[900]),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF1E293B),
        disabledForegroundColor: Colors.grey[700],
        elevation: active ? 5 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: EdgeInsets.zero,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: active ? Colors.white : Colors.grey[600],
        ),
      ),
    ),
  );
}

// ==========================================
// 4. หน้ากรรมการ (Referee Board Page) - ฉบับจับเวลาจริง + เพิ่มคะแนนเรียลไทม์ + รองรับ Blank + ระบบจบเกม
// ==========================================
class RefereeBoardPage extends StatefulWidget {
  final String adminName;
  final BluetoothCharacteristic? characteristic;

  const RefereeBoardPage({
    super.key,
    required this.adminName,
    this.characteristic,
  });

  @override
  State<RefereeBoardPage> createState() => _RefereeBoardPageState();
}

class _RefereeBoardPageState extends State<RefereeBoardPage> {
  // --- ตัวแปรสถานะเกม ---
  bool p1Ready = false, p2Ready = false, gameStarted = false;
  String lightStatus = "OFF";
  String lastAction = "WAITING FOR PLAYERS...";
  int currentActiveTurn = 1; // 1 = P1, 2 = P2

  // --- ตัวแปรเวลา (Timer) ---
  Timer? _gameTimer;
  int p1Seconds = 22 * 60; // 22 นาที = 1320 วินาที
  int p2Seconds = 22 * 60;

  // --- ตัวแปรสำหรับ Grid และ พิกัด ---
  Map<int, String> boardMemory = {};
  Map<int, String> confirmedBoard =
      {}; // 🌟 [เพิ่มใหม่] ตัวแปร Backup เก็บสถานะกระดานที่ถูกต้องล่าสุด

  int? startPoint; // จุดเริ่ม (S)
  int? endPoint; // จุดจบ (E)
  List<Map<String, dynamic>> gameHistory = [];
  StreamSubscription? _btStream;

  @override
  void initState() {
    super.initState();
    _setupBluetoothListener();
    _startGameLoop(); // เริ่มระบบ Loop เวลา
  }

  // ฟังก์ชันตัวนับเวลา (ทำงานทุก 1 วินาที)
  void _startGameLoop() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (gameStarted && lightStatus != "YELLOW") {
        // เวลาเดินเมื่อเกมเริ่ม และไม่ใช่ช่วงกรรมการตรวจ
        setState(() {
          if (currentActiveTurn == 1) {
            if (p1Seconds > 0) p1Seconds--;
          } else {
            if (p2Seconds > 0) p2Seconds--;
          }
        });
      }
    });
  }

  // ฟังก์ชันแปลงวินาทีเป็น MM:SS
  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // --- ฟังก์ชันดึงคะแนนล่าสุดจากประวัติ ---
  int _getLatestScore(String player) {
    if (gameHistory.isEmpty) return 0;
    try {
      final latestLog = gameHistory.firstWhere(
        (log) => log["player"] == player,
      );
      return latestLog["totalScore"];
    } catch (e) {
      return 0; // ถ้ายังไม่มีประวัติให้เริ่มที่ 0
    }
  }

  // --- ฟังก์ชันยืนยันการยุติเกม (กรรมการกดเอง) ---
  void _confirmEndGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ ยืนยันการยุติเกม?"),
        content: const Text("หากกดยืนยัน เกมจะจบลงทันทีและเข้าสู่หน้าสรุปผล"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context); // ปิด Dialog ยืนยัน
              _sendAction("REF:END_GAME"); // ส่งคำสั่งจบเกมไปที่ ESP32
            },
            child: const Text("ยุติเกม", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- ฟังก์ชันแสดงหน้าต่างสรุปผล (Summary Dialog) ---
  void _showGameOverDialog(String winner, String reason) {
    int p1FinalScore = _getLatestScore("P1");
    int p2FinalScore = _getLatestScore("P2");

    String winnerText;
    if (winner == "P1") {
      winnerText = "🏆 ผู้เล่น 1 ชนะ!";
    } else if (winner == "P2") {
      winnerText = "🏆 ผู้เล่น 2 ชนะ!";
    } else {
      winnerText = "🤝 เสมอกัน! (DRAW)";
    }

    String reasonText;
    if (reason == "PASS_LIMIT") {
      reasonText = "ไม่มีการวางเบี้ยติดต่อกันครบ 6 ครั้ง";
    } else if (reason == "REFEREE_DECISION") {
      reasonText = "ยุติโดยคำตัดสินของกรรมการ";
    } else {
      reasonText = "จบการแข่งขัน";
    }

    showDialog(
      context: context,
      barrierDismissible: false, // บังคับให้กดปุ่มเท่านั้น ห้ามปัดทิ้ง
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "🎉 สรุปผลการแข่งขัน",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                winnerText,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reasonText,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              const Divider(height: 30, thickness: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        "PLAYER 1",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "$p1FinalScore",
                        style: const TextStyle(
                          fontSize: 30,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        "PLAYER 2",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "$p2FinalScore",
                        style: const TextStyle(
                          fontSize: 30,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // ปิด Dialog
                Navigator.pop(context); // กลับไปหน้า Lobby / หน้าก่อนหน้า
              },
              child: const Text(
                "กลับหน้าหลัก",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(context); // ปิด Dialog
                _sendAction("REF:START"); // สั่ง ESP32 รีเซ็ตเกม

                // เคลียร์ค่าในแอปเพื่อเริ่มรอบใหม่
                setState(() {
                  gameStarted = false;
                  p1Ready = false;
                  p2Ready = false;
                  p1Seconds = 22 * 60;
                  p2Seconds = 22 * 60;
                  boardMemory.clear();
                  confirmedBoard
                      .clear(); // 🌟 [เพิ่มใหม่] ล้าง Backup กระดานด้วย
                  gameHistory.clear();
                  startPoint = null;
                  endPoint = null;
                  lightStatus = "OFF";
                  lastAction = "WAITING FOR PLAYERS...";
                  _startGameLoop();
                });
              },
              child: const Text(
                "เริ่มเกมใหม่",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- ฟังก์ชันแสดง Popup ให้กรรมการเลือกเบี้ยพิเศษ ---
  Future<String?> _showSpecialTokenDialog(String tokenType) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // บังคับให้ต้องกดเลือกตัวเลือกเท่านั้น
      builder: (BuildContext context) {
        if (tokenType == "+/-") {
          return AlertDialog(
            title: const Text('เลือกเครื่องหมาย', textAlign: TextAlign.center),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, "+"),
                  child: const Text("+", style: TextStyle(fontSize: 24)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, "-"),
                  child: const Text("-", style: TextStyle(fontSize: 24)),
                ),
              ],
            ),
          );
        } else if (tokenType == "x/÷") {
          return AlertDialog(
            title: const Text('เลือกเครื่องหมาย', textAlign: TextAlign.center),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, "x"),
                  child: const Text("x", style: TextStyle(fontSize: 24)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, "÷"),
                  child: const Text("÷", style: TextStyle(fontSize: 24)),
                ),
              ],
            ),
          );
        } else if (tokenType == "BLANK") {
          List<String> blankOptions = List.generate(
            21,
            (index) => index.toString(),
          );
          blankOptions.addAll(["+", "-", "x", "÷", "="]);
          return AlertDialog(
            title: const Text(
              'เบี้ย BLANK: เลือกค่าที่ต้องการ',
              textAlign: TextAlign.center,
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children: blankOptions.map((choice) {
                    return ElevatedButton(
                      onPressed: () => Navigator.pop(context, choice),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(50, 50),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(choice, style: const TextStyle(fontSize: 18)),
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // ฟังก์ชันดักฟังค่าจาก Bluetooth
  void _setupBluetoothListener() {
    _btStream = widget.characteristic?.lastValueStream.listen((value) {
      if (value.isEmpty) return;
      String msg = utf8.decode(value).trim();

      // ตรวจจับแจ้งเตือนเบี้ยซ้ำ
      if (msg == "MSG:DUPLICATE_TILE") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ ตรวจพบเบี้ยซ้ำ! กรุณาตรวจสอบและเปลี่ยนเบี้ย",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // ตรวจจับการจบเกม
      if (msg.startsWith("GAME_OVER:")) {
        _gameTimer?.cancel();
        List<String> parts = msg.split(":");
        String winner = parts.length > 1 ? parts[1] : "UNKNOWN";
        String reason = parts.length > 2 ? parts[2] : "";
        _showGameOverDialog(winner, reason);
        return;
      }

      // 🌟 [เพิ่มใหม่] ตรวจจับสมการผิดพลาด เพื่อลบเบี้ยที่เพิ่งวางทิ้ง
      if (msg == "MSG:WRONG_EQ") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "❌ สมการไม่ถูกต้อง! (เสียตาเดิน)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 3),
          ),
        );

        setState(() {
          // คืนค่ากระดานกลับไปยังจุดที่ถูกต้องล่าสุด (ลบเบี้ยที่สแกนในตานี้ออก)
          boardMemory = Map.from(confirmedBoard);
        });
        return;
      }

      setState(() {
        if (msg == "STATUS:P1_READY") p1Ready = true;
        if (msg == "STATUS:P2_READY") p2Ready = true;
        if (msg == "STATUS:ALL_READY") {
          p1Ready = true;
          p2Ready = true;
        }

        if (msg == "MSG:GAME_STARTED") {
          gameStarted = true;
          lastAction = "GAME ON!";
          boardMemory.clear();
          confirmedBoard
              .clear(); // 🌟 [เพิ่มใหม่] เริ่มเกมใหม่ต้องเคลียร์ Backup ด้วย
        }

        if (msg.startsWith("LIGHT:")) lightStatus = msg.substring(6);

        if (msg.startsWith("TURN:")) {
          currentActiveTurn = int.parse(msg.substring(5));
          lastAction = "TURN CHANGED: Player $currentActiveTurn";
          startPoint = null;
          endPoint = null;
        }

        // อ่านข้อความ SCAN
        if (msg.startsWith("SCAN:")) {
          try {
            List<String> parts = msg.split('|');
            int idx = int.parse(parts[1].split(':')[1]);
            String tokenText = parts[2].split(':')[1];

            if (tokenText == "BLANK" ||
                tokenText == "+/-" ||
                tokenText == "x/÷") {
              _showSpecialTokenDialog(tokenText).then((userChoice) {
                if (userChoice != null) {
                  _sendAction("CMD:CHOICE:$userChoice");
                  setState(() {
                    boardMemory[idx] = userChoice;
                  });
                }
              });
            } else {
              boardMemory[idx] = tokenText;
            }
          } catch (e) {
            print("Error parsing scan: $e");
          }
        }

        if (msg.startsWith("MSG:P")) {
          lastAction = msg.substring(4).replaceAll("_", " ");
        }

        if (msg.startsWith("HISTORY:")) {
          List<String> parts = msg.split(":");
          if (parts.length >= 6) {
            gameHistory.insert(0, {
              "player": parts[1],
              "turn": int.tryParse(parts[2]) ?? 0,
              "equation": parts[3],
              "turnScore": int.tryParse(parts[4]) ?? 0,
              "totalScore": int.tryParse(parts[5]) ?? 0,
            });

            // 🌟 [เพิ่มใหม่] ถ้าสมการถูกต้องและได้คะแนน ให้เซฟกระดานนี้เป็น Backup ล่าสุด
            confirmedBoard = Map.from(boardMemory);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _btStream?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _sendAction(String act) async {
    if (widget.characteristic != null) {
      await widget.characteristic!.write(utf8.encode(act));
    }
  }

  void _approveWithCoordinates() {
    if (startPoint == null || endPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("กรุณาเลือกจุดเริ่ม (S) และจุดจบ (E) ก่อน"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int startY = startPoint! ~/ 15;
    int startX = startPoint! % 15;
    int endY = endPoint! ~/ 15;
    int endX = endPoint! % 15;

    if (startX != endX && startY != endY) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("พิกัดผิดพลาด! ไม่สามารถวางเบี้ยแนวทแยงได้"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int tileCount = 0;
    if (startX == endX) {
      tileCount = (startY - endY).abs() + 1;
    } else {
      tileCount = (startX - endX).abs() + 1;
    }

    String command = "APPROVE:X${startX}Y${startY}:X${endX}Y${endY}:$tileCount";
    _sendAction(command);

    setState(() {
      startPoint = null;
      endPoint = null;
    });
  }

  void _showHistoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📝 GAME HISTORY",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(thickness: 2),
              Expanded(
                child: gameHistory.isEmpty
                    ? const Center(
                        child: Text(
                          "ยังไม่มีประวัติการเล่น",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: gameHistory.length,
                        itemBuilder: (context, index) {
                          final log = gameHistory[index];
                          bool isP1 = log["player"] == "P1";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isP1 ? Colors.green[50] : Colors.blue[50],
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isP1
                                    ? Colors.green
                                    : Colors.blueAccent,
                                child: Text(
                                  log["player"],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                log["equation"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Text("Turn: ${log["turn"]}"),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "+${log["turnScore"]}",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Total: ${log["totalScore"]}",
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("Referee: ${widget.adminName}"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 2,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                gameStarted ? "TIME ON" : "PAUSED",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
          if (gameStarted)
            IconButton(
              icon: const Icon(
                Icons.stop_circle_outlined,
                color: Colors.redAccent,
                size: 28,
              ),
              onPressed: _confirmEndGame,
              tooltip: "ยุติเกม (End Game)",
            ),
          IconButton(
            icon: const Icon(Icons.history_edu, color: Colors.blueAccent),
            onPressed: _showHistoryDialog,
            tooltip: "ดูประวัติการเล่น",
          ),
        ],
      ),
      body: Column(
        children: [
          _build3LEDStatus(),
          _buildLogBox(),
          Expanded(child: _buildGridBoard()),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _build3LEDStatus() {
    bool isRefTurn = (lightStatus == "YELLOW");

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ledLamp(
            "REFEREE",
            isRefTurn ? Colors.green : Colors.yellow,
            null,
            null,
          ),
          _ledLamp(
            "PLAYER 1",
            (gameStarted && currentActiveTurn == 1 && !isRefTurn)
                ? Colors.green
                : Colors.yellow,
            p1Seconds,
            _getLatestScore("P1"),
          ),
          _ledLamp(
            "PLAYER 2",
            (gameStarted && currentActiveTurn == 2 && !isRefTurn)
                ? Colors.green
                : Colors.yellow,
            p2Seconds,
            _getLatestScore("P2"),
          ),
        ],
      ),
    );
  }

  Widget _ledLamp(String label, Color color, int? timeLeft, int? score) {
    return Column(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.6),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: timeLeft != null
                ? const Icon(Icons.timer, size: 20, color: Colors.black38)
                : const Icon(Icons.gavel, size: 20, color: Colors.black38),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        if (timeLeft != null)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatTime(timeLeft),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          )
        else
          const SizedBox(height: 18),
        if (score != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Score: $score",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: label == "PLAYER 1"
                    ? Colors.green[700]
                    : Colors.blueAccent,
              ),
            ),
          )
        else
          const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLogBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(8),
      color: Colors.amber[50],
      child: Text(
        "STATUS: $lastAction",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildGridBoard() {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 15,
          ),
          itemCount: 225,
          itemBuilder: (context, index) {
            int r = index ~/ 15;
            int c = index % 15;

            Color boxColor = _getBoardColor(r, c);
            String text = _getBoardText(r, c);
            Color textColor = Colors.black54;
            FontWeight fontWeight = FontWeight.normal;

            if (index == startPoint) {
              boxColor = Colors.purple[700]!;
              text = "S";
              textColor = Colors.white;
              fontWeight = FontWeight.w900;
            } else if (index == endPoint) {
              boxColor = Colors.black;
              text = "E";
              textColor = Colors.white;
              fontWeight = FontWeight.w900;
            } else if (boardMemory.containsKey(index)) {
              boxColor = const Color(0xFFFFD54F);
              text = boardMemory[index]!;
              textColor = Colors.black;
              fontWeight = FontWeight.w900;
            }

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (startPoint == null) {
                    startPoint = index;
                  } else if (endPoint == null) {
                    endPoint = index;
                  } else {
                    startPoint = index;
                    endPoint = null;
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.all(0.5),
                color: boxColor,
                child: Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: boardMemory.containsKey(index)
                          ? 14
                          : ((text == "S" || text == "E") ? 10 : 6),
                      color: textColor,
                      fontWeight: fontWeight,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
      child: !gameStarted
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: (p1Ready && p2Ready)
                  ? () => _sendAction("REF:START")
                  : null,
              child: const Text(
                "START GAME (22 Mins)",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          : lightStatus == "YELLOW"
          ? Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _sendAction("REF:REJECT"),
                    child: const Text(
                      "REJECT",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _approveWithCoordinates,
                    child: const Text(
                      "APPROVE (Send)",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          : Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  "Waiting for Player $currentActiveTurn...",
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
    );
  }

  Color _getBoardColor(int r, int c) {
    if ((r == 0 || r == 7 || r == 14) && (c == 0 || c == 7 || c == 14)) {
      return (r == 7 && c == 7)
          ? const Color(0xFF38BDF8)
          : const Color(0xFFEF4444);
    }
    List<List<int>> yel = [
      [1, 1],
      [2, 2],
      [3, 3],
      [1, 13],
      [2, 12],
      [3, 11],
      [13, 1],
      [12, 2],
      [11, 3],
      [13, 13],
      [12, 12],
      [11, 11],
    ];
    for (var p in yel) {
      if (p[0] == r && p[1] == c) return const Color(0xFFFDE047);
    }
    List<List<int>> blu = [
      [1, 5],
      [1, 9],
      [5, 1],
      [5, 5],
      [5, 9],
      [5, 13],
      [9, 1],
      [9, 5],
      [9, 9],
      [9, 13],
      [13, 5],
      [13, 9],
      [4, 4],
      [4, 10],
      [10, 10],
      [10, 4],
    ];
    for (var p in blu) {
      if (p[0] == r && p[1] == c) return const Color(0xFF38BDF8);
    }
    List<List<int>> ora = [
      [0, 3],
      [0, 11],
      [2, 6],
      [2, 8],
      [3, 0],
      [3, 7],
      [3, 14],
      [6, 2],
      [6, 6],
      [6, 8],
      [6, 12],
      [7, 3],
      [7, 11],
      [8, 2],
      [8, 6],
      [8, 8],
      [8, 12],
      [11, 0],
      [11, 7],
      [11, 14],
      [12, 6],
      [12, 8],
      [14, 3],
      [14, 11],
    ];
    for (var p in ora) {
      if (p[0] == r && p[1] == c) return const Color(0xFFFB923C);
    }
    return const Color(0xFFD1FAE5);
  }

  String _getBoardText(int r, int c) {
    if (r == 7 && c == 7) return "★";
    Color col = _getBoardColor(r, c);
    if (col == const Color(0xFFEF4444)) return "3W";
    if (col == const Color(0xFFFDE047)) return "2W";
    if (col == const Color(0xFF38BDF8)) return "3L";
    if (col == const Color(0xFFFB923C)) return "2L";
    return "";
  }
}
