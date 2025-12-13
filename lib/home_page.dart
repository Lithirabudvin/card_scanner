import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:carousel_slider/carousel_slider.dart' as carousel;
import 'add_user_page.dart';
import 'users_list_page.dart';
import 'all_logs_page.dart';
import 'dashboard_page.dart';
import 'attendance_page.dart';
import 'auth_service.dart';
import 'signin_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final usersDb = FirebaseDatabase.instance.ref("users");
  final logsDb = FirebaseDatabase.instance.ref("logs");

  int totalUsers = 0;
  int activeUsers = 0;
  int todayEntries = 0;
  int todayExits = 0;
  int todayDenied = 0;
  int currentlyInside = 0;
  List<Map<String, dynamic>> recentLogs = [];
  Map<String, String> barcodeToName = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadQuickStats();
  }

  void loadQuickStats() {
    loadUsers();
    loadRecentActivity();
  }

  void loadUsers() {
    usersDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        int total = data.length;
        int active = 0;
        Map<String, String> mapping = {};

        data.forEach((barcodeId, value) {
          if (value["isActive"] == true) active++;
          mapping[barcodeId] = value["name"] ?? "Unknown";
        });

        if (mounted) {
          setState(() {
            totalUsers = total;
            activeUsers = active;
            barcodeToName = mapping;
          });
        }
      }
    });
  }

  void loadRecentActivity() {
    logsDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        String todayStr = _getTodayDate();
        int entries = 0;
        int exits = 0;
        int denied = 0;
        List<Map<String, dynamic>> recent = [];
        List<Map<String, dynamic>> allLogs = [];

        data.forEach((deviceId, deviceLogs) {
          if (deviceLogs is Map) {
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

                if (logData["status"] == "entry" ||
                    logData["status"] == "exit") {
                  allLogs.add({
                    "barcode": logData["barcode"] ?? "N/A",
                    "status": logData["status"] ?? "N/A",
                    "timestamp": logData["timestamp"] ?? "N/A",
                  });
                }
              } catch (e) {}
            });
          }
        });

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
    allLogs.sort((a, b) {
      try {
        DateTime timeA = DateTime.parse(a["timestamp"]);
        DateTime timeB = DateTime.parse(b["timestamp"]);
        return timeA.compareTo(timeB);
      } catch (e) {
        return 0;
      }
    });

    Set<String> inside = {};
    for (var log in allLogs) {
      if (log["status"] == "entry") {
        inside.add(log["barcode"]);
      } else if (log["status"] == "exit") {
        inside.remove(log["barcode"]);
      }
    }

    setState(() {
      currentlyInside = inside.length;
    });
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String formatTime(String timestamp) {
    try {
      DateTime dt = DateTime.parse(timestamp);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "";
    }
  }

  String getUserName(String barcode) {
    return barcodeToName[barcode] ?? "Unknown";
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

  void _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SignInPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Smart Door Admin',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadQuickStats,
          ),
        ],
      ),
      drawer: _buildDrawer(context, user),
      body: RefreshIndicator(
        onRefresh: () async {
          loadQuickStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade700,
                      Colors.blue.shade500,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      user?.displayName ?? 'Admin',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 20),

              // Today's Activity Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Activity",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTodayStatCard(
                            'Entries',
                            todayEntries.toString(),
                            Icons.login,
                            Colors.green,
                            200,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTodayStatCard(
                            'Exits',
                            todayExits.toString(),
                            Icons.logout,
                            Colors.orange,
                            300,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTodayStatCard(
                            'Denied',
                            todayDenied.toString(),
                            Icons.block,
                            Colors.red,
                            400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Quick Stats Overview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Quick Stats',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Access Carousel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Quick Access',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              carousel.CarouselSlider(
                options: carousel.CarouselOptions(
                  height: 200,
                  enlargeCenterPage: true,
                  enableInfiniteScroll: false,
                  viewportFraction: 0.85,
                ),
                items: [
                  _buildQuickAccessCard(
                    context,
                    'Dashboard',
                    'View complete overview',
                    Icons.dashboard_rounded,
                    [Colors.indigo.shade400, Colors.indigo.shade700],
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DashboardPage()),
                    ),
                  ),
                  _buildQuickAccessCard(
                    context,
                    'Add New User',
                    'Register users quickly',
                    Icons.person_add_rounded,
                    [Colors.blue.shade400, Colors.blue.shade700],
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddUserPage()),
                    ),
                  ),
                  _buildQuickAccessCard(
                    context,
                    'View Users',
                    'Manage all users',
                    Icons.people_rounded,
                    [Colors.green.shade400, Colors.green.shade700],
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UsersListPage()),
                    ),
                  ),
                  _buildQuickAccessCard(
                    context,
                    'Door Logs',
                    'Complete access history',
                    Icons.history_rounded,
                    [Colors.orange.shade400, Colors.orange.shade700],
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AllLogsPage()),
                    ),
                  ),
                  _buildQuickAccessCard(
                    context,
                    'Attendance',
                    'Track entry & exit times',
                    Icons.access_time_rounded,
                    [Colors.purple.shade400, Colors.purple.shade700],
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AttendancePage()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Recent Activity
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Activity',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AllLogsPage()),
                            );
                          },
                          child: Text(
                            'View All',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (recentLogs.isEmpty)
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
                                  'No recent activity',
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
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: getStatusColor(log["status"])
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                getStatusIcon(log["status"]),
                                color: getStatusColor(log["status"]),
                                size: 20,
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
                              formatTime(log["timestamp"]),
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
                                delay:
                                    Duration(milliseconds: 1000 + (index * 50)))
                            .slideX(begin: 0.2, end: 0);
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, User? user) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade700,
              Colors.blue.shade50,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Text(
                      user?.displayName?.substring(0, 1).toUpperCase() ?? 'A',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'Admin User',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              context,
              'Home',
              Icons.home,
              () => Navigator.pop(context),
              isSelected: true,
            ),
            _buildDrawerItem(
              context,
              'Dashboard',
              Icons.dashboard,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardPage()),
                );
              },
            ),
            const Divider(),
            _buildDrawerItem(
              context,
              'Add User',
              Icons.person_add,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddUserPage()),
                );
              },
            ),
            _buildDrawerItem(
              context,
              'View Users',
              Icons.people,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsersListPage()),
                );
              },
            ),
            const Divider(),
            _buildDrawerItem(
              context,
              'Attendance',
              Icons.access_time,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendancePage()),
                );
              },
            ),
            _buildDrawerItem(
              context,
              'Door Logs',
              Icons.history,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AllLogsPage()),
                );
              },
            ),
            const Divider(),
            _buildDrawerItem(
              context,
              'Sign Out',
              Icons.logout,
              () {
                Navigator.pop(context);
                _signOut(context);
              },
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isSelected = false,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.red.shade600
            : isSelected
                ? Colors.blue.shade700
                : Colors.grey.shade700,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isDestructive
              ? Colors.red.shade600
              : isSelected
                  ? Colors.blue.shade700
                  : Colors.grey.shade700,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onTap: onTap,
    );
  }

  Widget _buildTodayStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    int delay,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 14), // Reduced padding
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Added to prevent overflow
          children: [
            Icon(icon, size: 28, color: color), // Reduced from 32
            const SizedBox(height: 6), // Reduced from 8
            Flexible(
              // Made text flexible
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 22, // Reduced from 24
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              // Made text flexible
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10, // Reduced from 11
                  color: Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).scale();
  }

  Widget _buildQuickAccessCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    List<Color> gradient,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[1].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Icon(
                icon,
                size: 140,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20), // Reduced from 24
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Added to prevent overflow
                children: [
                  Container(
                    padding: const EdgeInsets.all(10), // Reduced from 12
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        size: 28, color: Colors.white), // Reduced from 32
                  ),
                  const SizedBox(height: 12), // Reduced from 16
                  Flexible(
                    // Made text flexible
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18, // Reduced from 20
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 3), // Reduced from 4
                  Flexible(
                    // Made text flexible
                    child: Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12, // Reduced from 13
                        color: Colors.white.withOpacity(0.9),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
