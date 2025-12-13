import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'all_logs_page.dart';
import 'attendance_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final usersDb = FirebaseDatabase.instance.ref("users");
  final logsDb = FirebaseDatabase.instance.ref("logs");

  // User statistics
  int totalUsers = 0;
  int activeUsers = 0;
  int allowedUsers = 0;

  // Today's activity
  int todayEntries = 0;
  int todayExits = 0;
  int todayDenied = 0;

  // Current inside (calculated from logs)
  int currentlyInside = 0;
  Map<String, int> insidePerGate = {};

  // Recent activity
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
          if (value["isActive"] == true) active++;
          if (value["access"] == "allowed") allowed++;
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
        List<Map<String, dynamic>> allLogs = [];
        List<Map<String, dynamic>> recent = [];

        // Collect all logs
        data.forEach((deviceId, deviceLogs) {
          if (deviceLogs is Map) {
            deviceLogs.forEach((logId, logData) {
              try {
                DateTime logDate = DateTime.parse(logData["timestamp"]);
                String logDateStr =
                    "${logDate.year}-${logDate.month.toString().padLeft(2, '0')}-${logDate.day.toString().padLeft(2, '0')}";

                // Count today's activity
                if (logDateStr == todayStr) {
                  if (logData["status"] == "entry") entries++;
                  if (logData["status"] == "exit") exits++;
                  if (logData["status"] == "denied") denied++;
                }

                // Collect for recent activity
                recent.add({
                  "barcode": logData["barcode"] ?? "N/A",
                  "status": logData["status"] ?? "N/A",
                  "timestamp": logData["timestamp"] ?? "N/A",
                  "deviceID": logData["deviceID"] ?? deviceId,
                });

                // Collect for current inside calculation
                if (logData["status"] == "entry" ||
                    logData["status"] == "exit") {
                  allLogs.add({
                    "barcode": logData["barcode"] ?? "N/A",
                    "status": logData["status"] ?? "N/A",
                    "timestamp": logData["timestamp"] ?? "N/A",
                    "deviceID": logData["deviceID"] ?? deviceId,
                  });
                }
              } catch (e) {}
            });
          }
        });

        // Sort recent logs
        recent.sort((a, b) {
          try {
            DateTime timeA = DateTime.parse(a["timestamp"]);
            DateTime timeB = DateTime.parse(b["timestamp"]);
            return timeB.compareTo(timeA);
          } catch (e) {
            return 0;
          }
        });
        recent = recent.take(8).toList();

        // Calculate current inside
        _calculateCurrentInside(allLogs);

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

  void _calculateCurrentInside(List<Map<String, dynamic>> allLogs) {
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

    // Track who's inside per gate
    Map<String, Set<String>> insideByGate = {};
    Map<String, String> lastStatusByUserGate = {};

    for (var log in allLogs) {
      String barcode = log["barcode"];
      String deviceId = log["deviceID"];
      String status = log["status"];
      String key = "$barcode-$deviceId";

      if (status == "entry") {
        if (!insideByGate.containsKey(deviceId)) {
          insideByGate[deviceId] = {};
        }
        insideByGate[deviceId]!.add(barcode);
        lastStatusByUserGate[key] = "entry";
      } else if (status == "exit") {
        if (insideByGate.containsKey(deviceId)) {
          insideByGate[deviceId]!.remove(barcode);
        }
        lastStatusByUserGate[key] = "exit";
      }
    }

    // Count total and per-gate
    int total = 0;
    Map<String, int> perGate = {};

    insideByGate.forEach((gate, people) {
      total += people.length;
      perGate[gate] = people.length;
    });

    setState(() {
      currentlyInside = total;
      insidePerGate = perGate;
    });
  }

  String getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String formatTimestamp(String timestamp) {
    try {
      DateTime dt = DateTime.parse(timestamp);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
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
      backgroundColor: Colors.grey.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade700,
              Colors.indigo.shade500,
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
                                'Dashboard',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'System Overview',
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
                          onPressed: loadDashboardData,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // System Status Card
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade600,
                                      Colors.blue.shade800,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.security,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Smart Door System",
                                            style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Colors.greenAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "System Active • $totalUsers Users",
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  fontSize: 13,
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
                            )
                                .animate()
                                .fadeIn(delay: 100.ms)
                                .slideY(begin: 0.1, end: 0),

                            const SizedBox(height: 24),

                            // Currently Inside Section
                            Text(
                              "Currently Inside",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),

                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AttendancePage(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green.shade400,
                                        Colors.green.shade600
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                currentlyInside.toString(),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 48,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                "People Inside",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Icon(
                                            Icons.person_pin_circle,
                                            size: 64,
                                            color:
                                                Colors.white.withOpacity(0.3),
                                          ),
                                        ],
                                      ),
                                      if (insidePerGate.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        const Divider(
                                            color: Colors.white54, height: 1),
                                        const SizedBox(height: 16),
                                        ...insidePerGate.entries.map((entry) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.door_front_door,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      entry.key,
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    "${entry.value}",
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(delay: 200.ms).scale(),

                            const SizedBox(height: 24),

                            // User Statistics
                            Text(
                              "User Statistics",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    "Total Users",
                                    totalUsers.toString(),
                                    Icons.people,
                                    [
                                      Colors.blue.shade400,
                                      Colors.blue.shade600
                                    ],
                                    300,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    "Active",
                                    activeUsers.toString(),
                                    Icons.check_circle,
                                    [
                                      Colors.green.shade400,
                                      Colors.green.shade600
                                    ],
                                    400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              "Allowed Access",
                              allowedUsers.toString(),
                              Icons.verified_user,
                              [Colors.teal.shade400, Colors.teal.shade600],
                              500,
                            ),

                            const SizedBox(height: 24),

                            // Today's Activity
                            Text(
                              "Today's Activity",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    "Entries",
                                    todayEntries.toString(),
                                    Icons.login,
                                    [
                                      Colors.green.shade400,
                                      Colors.green.shade600
                                    ],
                                    600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    "Exits",
                                    todayExits.toString(),
                                    Icons.logout,
                                    [
                                      Colors.orange.shade400,
                                      Colors.orange.shade600
                                    ],
                                    700,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    "Denied",
                                    todayDenied.toString(),
                                    Icons.block,
                                    [Colors.red.shade400, Colors.red.shade600],
                                    800,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Recent Activity
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Recent Activity",
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AllLogsPage(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "View All",
                                    style: GoogleFonts.poppins(
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (recentLogs.isEmpty)
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "No recent activity",
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...recentLogs.asMap().entries.map((entry) {
                                final index = entry.key;
                                final log = entry.value;
                                return Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: getStatusColor(log["status"])
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        getStatusIcon(log["status"]),
                                        color: getStatusColor(log["status"]),
                                      ),
                                    ),
                                    title: Text(
                                      getUserName(log["barcode"]),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${log["status"].toString().toUpperCase()} • ${log["deviceID"]}",
                                      style: GoogleFonts.poppins(fontSize: 12),
                                    ),
                                    trailing: Text(
                                      formatTimestamp(log["timestamp"]),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                )
                                    .animate()
                                    .fadeIn(
                                        delay: Duration(
                                            milliseconds: 900 + (index * 50)))
                                    .slideX(begin: 0.2, end: 0);
                              }),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    List<Color> gradient,
    int delay,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).scale();
  }
}
