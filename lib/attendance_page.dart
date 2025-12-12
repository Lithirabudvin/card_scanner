import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  final attendanceDb = FirebaseDatabase.instance.ref("attendance");
  final currentInsideDb = FirebaseDatabase.instance.ref("current_inside");

  List<Map<String, dynamic>> currentInside = [];
  List<Map<String, dynamic>> attendanceRecords = [];
  bool isLoading = true;

  late TabController _tabController;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void loadData() async {
    setState(() => isLoading = true);
    loadCurrentInside();
    loadAttendanceRecords();
  }

  void loadCurrentInside() {
    currentInsideDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        List<Map<String, dynamic>> loaded = [];
        data.forEach((key, value) {
          loaded.add({
            "userId": value["userId"] ?? "N/A",
            "userName": value["userName"] ?? "N/A",
            "barcodeId": value["barcodeId"] ?? "N/A",
            "entranceTime": value["entranceTime"] ?? 0,
            "sessionId": value["sessionId"] ?? "N/A",
          });
        });

        if (mounted) {
          setState(() {
            currentInside = loaded;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            currentInside = [];
            isLoading = false;
          });
        }
      }
    });
  }

  void loadAttendanceRecords() {
    attendanceDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        List<Map<String, dynamic>> loaded = [];

        data.forEach((userId, sessions) {
          if (sessions is Map) {
            sessions.forEach((sessionId, sessionData) {
              loaded.add({
                "sessionId": sessionId,
                "userId": sessionData["userId"] ?? "N/A",
                "userName": sessionData["userName"] ?? "N/A",
                "barcodeId": sessionData["barcodeId"] ?? "N/A",
                "entranceTime": sessionData["entranceTime"] ?? 0,
                "exitTime": sessionData["exitTime"],
                "duration": sessionData["duration"],
                "date": sessionData["date"] ?? "N/A",
                "status": sessionData["status"] ?? "N/A",
              });
            });
          }
        });

        // Sort by entrance time (most recent first)
        loaded.sort((a, b) => b["entranceTime"].compareTo(a["entranceTime"]));

        if (mounted) {
          setState(() {
            attendanceRecords = loaded;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            attendanceRecords = [];
          });
        }
      }
    });
  }

  String formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) return "N/A";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
  }

  String formatDuration(int? milliseconds) {
    if (milliseconds == null || milliseconds == 0) return "N/A";

    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return "${hours}h ${minutes}m ${seconds}s";
  }

  String getTimeSince(int timestamp) {
    final now = DateTime.now();
    final entrance = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(entrance);

    if (diff.inHours > 0) {
      return "${diff.inHours}h ${diff.inMinutes.remainder(60)}m ago";
    } else if (diff.inMinutes > 0) {
      return "${diff.inMinutes}m ago";
    } else {
      return "${diff.inSeconds}s ago";
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  List<Map<String, dynamic>> getFilteredRecords() {
    final dateStr =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    return attendanceRecords
        .where((record) => record["date"] == dateStr)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Tracking"),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Currently Inside", icon: Icon(Icons.person_pin)),
            Tab(text: "All Records", icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCurrentInsideTab(),
                _buildAttendanceRecordsTab(),
              ],
            ),
    );
  }

  Widget _buildCurrentInsideTab() {
    return currentInside.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No one is currently inside"),
              ],
            ),
          )
        : ListView.builder(
            itemCount: currentInside.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final person = currentInside[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                color: Colors.green.shade50,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    person["userName"],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                          "Entered: ${formatTimestamp(person["entranceTime"])}"),
                      Text("Duration: ${getTimeSince(person["entranceTime"])}"),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            },
          );
  }

  Widget _buildAttendanceRecordsTab() {
    final filteredRecords = getFilteredRecords();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => selectDate(context),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text("Select Date"),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredRecords.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No records for this date"),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredRecords.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final record = filteredRecords[index];
                    final isCompleted = record["status"] == "completed";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isCompleted ? Colors.blue : Colors.orange,
                          child: Text(
                            record["userName"][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          record["userName"],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isCompleted ? "Completed" : "Currently Inside",
                          style: TextStyle(
                            color: isCompleted ? Colors.green : Colors.orange,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildDetailRow("User ID", record["userId"]),
                                _buildDetailRow("Entrance",
                                    formatTimestamp(record["entranceTime"])),
                                _buildDetailRow("Exit",
                                    formatTimestamp(record["exitTime"])),
                                _buildDetailRow("Duration",
                                    formatDuration(record["duration"])),
                                _buildDetailRow("Date", record["date"]),
                                _buildDetailRow("Status",
                                    record["status"].toString().toUpperCase()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
