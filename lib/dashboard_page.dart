import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final usersDb = FirebaseDatabase.instance.ref("users");
  final logsDb = FirebaseDatabase.instance.ref("logs");

  int totalUsers = 0;
  int activeUsers = 0;
  int allowedUsers = 0;
  int todayEntries = 0;
  int todayExits = 0;
  int todayDenied = 0;

  Map<String, String> barcodeToName = {};
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
  }

  void loadUsers() {
    usersDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        int total = data.length;
        int active = 0;
        int allowed = 0;
        Map<String, String> mapping = {};

        data.forEach((barcodeId, value) {
          if (value["isActive"] == true) {
            active++;
          }
          if (value["access"] == "allowed") {
            allowed++;
          }
          mapping[barcodeId] = value["name"] ?? "Unknown";
        });

        if (mounted) {
          setState(() {
            totalUsers = total;
            activeUsers = active;
            allowedUsers = allowed;
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
        String todayStr = getTodayDate();
        int entries = 0;
        int exits = 0;
        int denied = 0;
        List<Map<String, dynamic>> recent = [];

        // Loop through all devices
        data.forEach((deviceId, deviceLogs) {
          if (deviceLogs is Map) {
            // Loop through logs for this device
            deviceLogs.forEach((logId, logData) {
              try {
                DateTime logDate = DateTime.parse(logData["timestamp"]);
                String logDateStr =
                    "${logDate.year}-${logDate.month.toString().padLeft(2, '0')}-${logDate.day.toString().padLeft(2, '0')}";

                if (logDateStr == todayStr) {
                  if (logData["status"] == "entry") entries++;
                  if (logData["status"] == "exit") exits++;
                  if (logData["status"] == "denied") denied++;
                }

                recent.add({
                  "barcode": logData["barcode"] ?? "N/A",
                  "status": logData["status"] ?? "N/A",
                  "timestamp": logData["timestamp"] ?? "N/A",
                  "deviceID": logData["deviceID"] ?? deviceId,
                });
              } catch (e) {
                // Skip invalid logs
              }
            });
          }
        });

        // Sort and get top 5 recent logs
        recent.sort((a, b) {
          try {
            DateTime timeA = DateTime.parse(a["timestamp"]);
            DateTime timeB = DateTime.parse(b["timestamp"]);
            return timeB.compareTo(timeA);
          } catch (e) {
            return 0;
          }
        });
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

  String getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String formatTimestamp(String timestamp) {
    try {
      DateTime dt = DateTime.parse(timestamp);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
    } catch (e) {
      return timestamp;
    }
  }

  String getUserName(String barcode) {
    return barcodeToName[barcode] ?? "Unknown User";
  }

  IconData getStatusIcon(String status) {
    if (status == "entry") return Icons.login;
    if (status == "exit") return Icons.logout;
    if (status == "denied") return Icons.block;
    return Icons.event;
  }

  Color getStatusColor(String status) {
    if (status == "entry") return Colors.green;
    if (status == "exit") return Colors.orange;
    if (status == "denied") return Colors.red;
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
                  // System Status Card
                  Card(
                    elevation: 4,
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.security,
                            size: 48,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Smart Door System",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "System Active • $totalUsers Users Registered",
                                  style: TextStyle(color: Colors.grey[700]),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          "Allowed",
                          allowedUsers.toString(),
                          Icons.verified_user,
                          Colors.teal,
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
                              backgroundColor: getStatusColor(log["status"]),
                              child: Icon(
                                getStatusIcon(log["status"]),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              getUserName(log["barcode"]),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${log["status"].toString().toUpperCase()} • ${log["deviceID"]} • ${formatTimestamp(log["timestamp"])}",
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
