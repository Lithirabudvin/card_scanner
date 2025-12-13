import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  final logsDb = FirebaseDatabase.instance.ref("logs");
  final usersDb = FirebaseDatabase.instance.ref("users");

  Map<String, Map<String, dynamic>> currentInsideByGate = {};
  List<Map<String, dynamic>> attendanceRecords = [];
  Map<String, String> barcodeToName = {};
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
    loadUsers();
    loadLogs();
  }

  void loadUsers() {
    usersDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        Map<String, String> mapping = {};
        data.forEach((barcodeId, userData) {
          mapping[barcodeId] = userData["name"] ?? "Unknown";
        });

        if (mounted) {
          setState(() {
            barcodeToName = mapping;
          });
        }
      }
    });
  }

  void loadLogs() {
    logsDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        // Process all logs
        List<Map<String, dynamic>> allLogs = [];

        data.forEach((deviceId, deviceLogs) {
          if (deviceLogs is Map) {
            deviceLogs.forEach((logId, logData) {
              if (logData["status"] == "entry" || logData["status"] == "exit") {
                allLogs.add({
                  "logId": logId,
                  "barcode": logData["barcode"] ?? "N/A",
                  "timestamp": logData["timestamp"] ?? "N/A",
                  "status": logData["status"] ?? "N/A",
                  "deviceID": logData["deviceID"] ?? deviceId,
                });
              }
            });
          }
        });

        // Sort by timestamp
        allLogs.sort((a, b) {
          try {
            DateTime timeA = DateTime.parse(a["timestamp"]);
            DateTime timeB = DateTime.parse(b["timestamp"]);
            return timeA.compareTo(timeB);
          } catch (e) {
            return 0;
          }
        });

        // Calculate current inside and attendance sessions
        _calculateAttendance(allLogs);
      } else {
        if (mounted) {
          setState(() {
            currentInsideByGate = {};
            attendanceRecords = [];
            isLoading = false;
          });
        }
      }
    });
  }

  void _calculateAttendance(List<Map<String, dynamic>> allLogs) {
    Map<String, Map<String, dynamic>> insideByGate = {};
    List<Map<String, dynamic>> sessions = [];

    // Track last entry per user per gate
    Map<String, Map<String, dynamic>> lastEntryByUserAndGate = {};

    for (var log in allLogs) {
      String barcode = log["barcode"];
      String deviceId = log["deviceID"];
      String status = log["status"];
      DateTime timestamp;

      try {
        timestamp = DateTime.parse(log["timestamp"]);
      } catch (e) {
        continue;
      }

      String userGateKey = "$barcode-$deviceId";

      if (status == "entry") {
        // User entered a gate
        lastEntryByUserAndGate[userGateKey] = {
          "barcode": barcode,
          "deviceID": deviceId,
          "entryTime": timestamp,
          "entryTimestamp": log["timestamp"],
        };

        // Update current inside for this gate
        insideByGate[userGateKey] = {
          "barcode": barcode,
          "userName": barcodeToName[barcode] ?? "Unknown User",
          "deviceID": deviceId,
          "entranceTime": timestamp.millisecondsSinceEpoch,
          "entranceTimestamp": log["timestamp"],
        };
      } else if (status == "exit") {
        // User exited - find matching entry
        if (lastEntryByUserAndGate.containsKey(userGateKey)) {
          var entry = lastEntryByUserAndGate[userGateKey]!;
          DateTime entryTime = entry["entryTime"] as DateTime;
          int duration = timestamp.difference(entryTime).inMilliseconds;

          // Create completed session
          sessions.add({
            "barcode": barcode,
            "userName": barcodeToName[barcode] ?? "Unknown User",
            "deviceID": deviceId,
            "entranceTime": entryTime.millisecondsSinceEpoch,
            "exitTime": timestamp.millisecondsSinceEpoch,
            "duration": duration,
            "date": DateFormat('yyyy-MM-dd').format(entryTime),
            "status": "completed",
            "entryTimestamp": entry["entryTimestamp"],
            "exitTimestamp": log["timestamp"],
          });

          // Remove from current inside
          insideByGate.remove(userGateKey);
          lastEntryByUserAndGate.remove(userGateKey);
        }
      }
    }

    // Add in-progress sessions (still inside)
    lastEntryByUserAndGate.forEach((userGateKey, entry) {
      DateTime entryTime = entry["entryTime"] as DateTime;
      sessions.add({
        "barcode": entry["barcode"],
        "userName": barcodeToName[entry["barcode"]] ?? "Unknown User",
        "deviceID": entry["deviceID"],
        "entranceTime": entryTime.millisecondsSinceEpoch,
        "exitTime": null,
        "duration": null,
        "date": DateFormat('yyyy-MM-dd').format(entryTime),
        "status": "in_progress",
        "entryTimestamp": entry["entryTimestamp"],
        "exitTimestamp": null,
      });
    });

    // Sort sessions by entry time (most recent first)
    sessions.sort((a, b) => b["entranceTime"].compareTo(a["entranceTime"]));

    if (mounted) {
      setState(() {
        currentInsideByGate = insideByGate;
        attendanceRecords = sessions;
        isLoading = false;
      });
    }
  }

  String formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) return "N/A";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  String formatDuration(int? milliseconds) {
    if (milliseconds == null || milliseconds == 0) return "N/A";

    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return "${hours}h ${minutes}m";
  }

  String getTimeSince(int timestamp) {
    final now = DateTime.now();
    final entrance = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(entrance);

    if (diff.inHours > 0) {
      return "${diff.inHours}h ${diff.inMinutes.remainder(60)}m";
    } else if (diff.inMinutes > 0) {
      return "${diff.inMinutes}m";
    } else {
      return "Just now";
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.purple.shade600,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  List<Map<String, dynamic>> getFilteredRecords() {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    return attendanceRecords
        .where((record) => record["date"] == dateStr)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade700,
              Colors.purple.shade500,
              Colors.white,
            ],
            stops: const [0.0, 0.2, 0.2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attendance',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Gate-wise tracking',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: loadData,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.purple.shade700,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  indicatorColor: Colors.purple.shade700,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_pin, size: 20),
                          const SizedBox(width: 8),
                          Text("Inside (${currentInsideByGate.length})"),
                        ],
                      ),
                    ),
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 20),
                          SizedBox(width: 8),
                          Text("Records"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCurrentInsideTab(),
                          _buildAttendanceRecordsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentInsideTab() {
    if (currentInsideByGate.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "No one is currently inside",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // Group by gate
    Map<String, List<Map<String, dynamic>>> byGate = {};
    currentInsideByGate.forEach((key, person) {
      String gate = person["deviceID"];
      if (!byGate.containsKey(gate)) {
        byGate[gate] = [];
      }
      byGate[gate]!.add(person);
    });

    return ListView(
      padding: const EdgeInsets.all(20),
      children: byGate.entries.map((entry) {
        String gate = entry.key;
        List<Map<String, dynamic>> people = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gate Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade600, Colors.purple.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.door_front_door, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    gate,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${people.length} inside",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // People inside this gate
            ...people.asMap().entries.map((personEntry) {
              int index = personEntry.key;
              var person = personEntry.value;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade50,
                        Colors.white,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              person["userName"][0].toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person["userName"],
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Entered ${getTimeSince(person["entranceTime"])} ago",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatTimestamp(person["entranceTime"]),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green.shade700,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 100 * index))
                  .slideX(begin: -0.2, end: 0);
            }).toList(),

            const SizedBox(height: 20),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAttendanceRecordsTab() {
    final filteredRecords = getFilteredRecords();

    return Column(
      children: [
        // Date Selector
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade50,
                        Colors.purple.shade100,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.purple.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('MMMM dd, yyyy').format(selectedDate),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => selectDate(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.edit_calendar),
              ),
            ],
          ),
        ),

        // Records List
        Expanded(
          child: filteredRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No records for this date",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredRecords.length,
                  padding: const EdgeInsets.all(20),
                  itemBuilder: (context, index) {
                    final record = filteredRecords[index];
                    final isCompleted = record["status"] == "completed";

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.all(16),
                          childrenPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isCompleted
                                    ? [
                                        Colors.blue.shade400,
                                        Colors.blue.shade600
                                      ]
                                    : [
                                        Colors.orange.shade400,
                                        Colors.orange.shade600
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                record["userName"][0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            "${record["userName"]} @ ${record["deviceID"]}",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (isCompleted
                                          ? Colors.blue
                                          : Colors.orange)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isCompleted ? "COMPLETED" : "IN PROGRESS",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isCompleted
                                        ? Colors.blue.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  _buildDetailRow(
                                    "Gate",
                                    record["deviceID"],
                                    Icons.door_front_door,
                                    Colors.purple,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDetailRow(
                                    "Entrance",
                                    formatTimestamp(record["entranceTime"]),
                                    Icons.login,
                                    Colors.green,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDetailRow(
                                    "Exit",
                                    formatTimestamp(record["exitTime"]),
                                    Icons.logout,
                                    Colors.red,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDetailRow(
                                    "Duration",
                                    formatDuration(record["duration"]),
                                    Icons.timelapse,
                                    Colors.blue,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 50 * index))
                        .slideX(begin: 0.2, end: 0);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
