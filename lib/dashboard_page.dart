import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final usersDb = FirebaseDatabase.instance.ref("users");
  final logsDb = FirebaseDatabase.instance.ref("door_logs");
  final doorDb = FirebaseDatabase.instance.ref("door_control");

  int totalUsers = 0;
  int activeUsers = 0;
  int todayEntries = 0;
  int todayExits = 0;
  int todayDenied = 0;
  String doorStatus = "locked";
  String lastAccessUser = "N/A";
  String lastAccessEvent = "N/A";
  int lastAccessTime = 0;

  List<Map<String, dynamic>> recentLogs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  void loadDashboardData() {
    setState(() => isLoading = true);
    loadUsers();
    loadLogs();
    loadDoorStatus();
  }

  void loadUsers() {
    usersDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        int total = data.length;
        int active = 0;

        data.forEach((key, value) {
          if (value["isActive"] == true) {
            active++;
          }
        });

        if (mounted) {
          setState(() {
            totalUsers = total;
            activeUsers = active;
          });
        }
      }
    });
  }

  void loadLogs() {
    logsDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        String todayStr = getTodayDate();
        int entries = 0;
        int exits = 0;
        int denied = 0;
        List<Map<String, dynamic>> recent = [];

        data.forEach((key, value) {
          if (value["date"] == todayStr) {
            if (value["event"] == "entrance") entries++;
            if (value["event"] == "exit") exits++;
            if (value["event"] == "access_denied") denied++;
          }

          recent.add({
            "logId": key,
            "userName": value["userName"] ?? "N/A",
            "event": value["event"] ?? "N/A",
            "timestamp": value["timestamp"] ?? 0,
            "date": value["date"] ?? "N/A",
            "time": value["time"] ?? "N/A",
          });
        });

        // Sort and get top 5 recent logs
        recent.sort((a, b) => b["timestamp"].compareTo(a["timestamp"]));
        recent = recent.take(5).toList();

        if (mounted) {
          setState(() {
            todayEntries = entries;
            todayExits = exits;
            todayDenied = denied;
            recentLogs = recent;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    });
  }

  void loadDoorStatus() {
    doorDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        if (mounted) {
          setState(() {
            doorStatus = data["lockState"] ?? "locked";
            lastAccessUser = data["lastAccessUser"] ?? "N/A";
            lastAccessEvent = data["lastAccessEvent"] ?? "N/A";
            lastAccessTime = data["lastAccessTime"] ?? 0;
          });
        }
      }
    });
  }

  String getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String formatTimestamp(int timestamp) {
    if (timestamp == 0) return "N/A";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
  }

  IconData getEventIcon(String event) {
    if (event == "entrance") return Icons.login;
    if (event == "exit") return Icons.logout;
    if (event == "access_denied") return Icons.block;
    return Icons.event;
  }

  Color getEventColor(String event) {
    if (event == "entrance") return Colors.green;
    if (event == "exit") return Colors.orange;
    if (event == "access_denied") return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadDashboardData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Door Status Card
                  Card(
                    elevation: 4,
                    color: doorStatus == "locked"
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(
                            doorStatus == "locked"
                                ? Icons.lock
                                : Icons.lock_open,
                            size: 48,
                            color: doorStatus == "locked"
                                ? Colors.red
                                : Colors.green,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Door is ${doorStatus.toUpperCase()}",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: doorStatus == "locked"
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (lastAccessUser != "N/A")
                                  Text(
                                    "Last: $lastAccessEvent by $lastAccessUser",
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                if (lastAccessTime != 0)
                                  Text(
                                    "Time: ${formatTimestamp(lastAccessTime)}",
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // User Statistics
                  const Text(
                    "User Statistics",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "Total Users",
                          totalUsers.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          "Active Users",
                          activeUsers.toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Today's Activity
                  const Text(
                    "Today's Activity",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "Entries",
                          todayEntries.toString(),
                          Icons.login,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          "Exits",
                          todayExits.toString(),
                          Icons.logout,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          "Denied",
                          todayDenied.toString(),
                          Icons.block,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Recent Activity
                  const Text(
                    "Recent Activity",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (recentLogs.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text("No recent activity"),
                        ),
                      ),
                    )
                  else
                    ...recentLogs.map((log) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: getEventColor(log["event"]),
                              child: Icon(
                                getEventIcon(log["event"]),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              log["userName"],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${log["event"].toString().toUpperCase().replaceAll("_", " ")} • ${log["date"]} at ${log["time"]}",
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
