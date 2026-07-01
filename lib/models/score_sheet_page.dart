import 'package:flutter/material.dart';
import 'dart:convert'; // สำคัญมาก! ใช้สำหรับถอดรหัส JSON 📦

// 1. Model สำหรับแปลง JSON
class ScoreRecord {
  final int turn;
  final String player;
  final String equation;
  final int points;
  final int total;

  ScoreRecord({
    required this.turn,
    required this.player,
    required this.equation,
    required this.points,
    required this.total,
  });

  // ฟังก์ชันสำหรับเปลี่ยน String JSON ให้กลายเป็น Object ScoreRecord
  factory ScoreRecord.fromJson(String source) {
    final Map<String, dynamic> data = json.decode(source);
    return ScoreRecord(
      turn: data['turn'],
      player: data['player'],
      equation: data['equation'],
      points: data['points'],
      total: data['total'],
    );
  }
}

class ScoreSheetPage extends StatefulWidget {
  const ScoreSheetPage({super.key});

  @override
  State<ScoreSheetPage> createState() => _ScoreSheetPageState();
}

class _ScoreSheetPageState extends State<ScoreSheetPage> {
  List<ScoreRecord> scoreHistory = [];

  // 🧪 ฟังก์ชันจำลองการได้รับข้อมูล (ในอนาคตจะเรียกใช้เมื่อ Bluetooth ได้รับค่า)
  void _addNewScore(String jsonString) {
    setState(() {
      scoreHistory.insert(
        0,
        ScoreRecord.fromJson(jsonString),
      ); // เพิ่มแถวใหม่ไว้บนสุด
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🏆 Live Score Board"),
        centerTitle: true,
        elevation: 10,
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // ส่วนแสดงผลตารางคะแนน
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection:
                        Axis.horizontal, // ให้เลื่อนซ้ายขวาได้ถ้าจอมือถือแคบ
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        Colors.indigo.withOpacity(0.1),
                      ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Turn',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Player',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Equation',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Score',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: scoreHistory
                          .map(
                            (record) => DataRow(
                              cells: [
                                DataCell(Text(record.turn.toString())),
                                DataCell(
                                  Text(
                                    record.player,
                                    style: TextStyle(
                                      color: record.player == "P1"
                                          ? Colors.blue
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(Text(record.equation)),
                                DataCell(
                                  Text(
                                    "+${record.points}",
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    record.total.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // ปุ่มทดสอบจำลองการส่งค่าจาก ESP32
            ElevatedButton.icon(
              onPressed: () {
                // จำลอง JSON ที่ ESP32 จะส่งมา
                String mockJson =
                    '{"turn": ${scoreHistory.length + 1}, "player": "P1", "equation": "10+5=15", "points": 25, "total": 100}';
                _addNewScore(mockJson);
              },
              icon: const Icon(Icons.add),
              label: const Text("จำลองการส่งข้อมูลจาก ESP32"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
