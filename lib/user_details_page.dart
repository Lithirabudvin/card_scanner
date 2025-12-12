import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UserDetailsPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserDetailsPage({super.key, required this.user});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage>
    with SingleTickerProviderStateMixin {
  final logsDb = FirebaseDatabase.instance.ref("logs");
  List<Map<String, dynamic>> userLogs = [];
  bool isLoading = true;

  String selectedFilter = "all";
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadUserLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void loadUserLogs() async {
    setState(() => isLoading = true);

    logsDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        List<Map<String, dynamic>> loaded = [];

        data.forEach((deviceId, deviceLogs) {
          if (deviceLogs is Map) {
            deviceLogs.forEach((logId, logData) {
              if (logData["barcode"] == widget.user["barcodeId"]) {
                loaded.add({
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

        loaded.sort((a, b) {
          try {
            DateTime timeA = DateTime.parse(a["timestamp"]);
            DateTime timeB = DateTime.parse(b["timestamp"]);
            return timeB.compareTo(timeA);
          } catch (e) {
            return 0;
          }
        });

        if (mounted) {
          setState(() {
            userLogs = loaded;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            userLogs = [];
            isLoading = false;
          });
        }
      }
    });
  }

  List<Map<String, dynamic>> getFilteredLogs() {
    if (selectedFilter == "all") return userLogs;
    return userLogs.where((log) => log["status"] == selectedFilter).toList();
  }

  String formatTimestamp(String timestamp) {
    try {
      DateTime dt = DateTime.parse(timestamp);
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return timestamp;
    }
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

  Map<String, int> getStatistics() {
    int totalEntries = userLogs.where((log) => log["status"] == "entry").length;
    int totalExits = userLogs.where((log) => log["status"] == "exit").length;
    int totalDenied = userLogs.where((log) => log["status"] == "denied").length;

    return {
      "totalEntries": totalEntries,
      "totalExits": totalExits,
      "totalDenied": totalDenied,
      "totalLogs": userLogs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = getStatistics();
    final filteredLogs = getFilteredLogs();
    final isAllowed = widget.user["access"] == "allowed";
    final isActive = widget.user["isActive"];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isActive && isAllowed
                  ? Colors.green.shade700
                  : Colors.grey.shade600,
              isActive && isAllowed
                  ? Colors.green.shade500
                  : Colors.grey.shade400,
              Colors.white,
            ],
            stops: const [0.0, 0.25, 0.25],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with User Info
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
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Edit feature coming soon!',
                                  style: GoogleFonts.poppins(),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // User Avatar
                    Hero(
                      tag: 'user_${widget.user["barcodeId"]}',
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isActive && isAllowed
                                ? [Colors.white, Colors.white.withOpacity(0.9)]
                                : [Colors.grey.shade300, Colors.grey.shade400],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.user["name"][0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: isActive && isAllowed
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ).animate().scale(duration: 400.ms),

                    const SizedBox(height: 16),

                    // User Name
                    Text(
                      widget.user["name"],
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 8),

                    // Role & Status Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.user["role"].toString().toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isAllowed
                                ? Colors.green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.user["access"].toString().toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? "ACTIVE" : "INACTIVE",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
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
                          labelColor: Colors.blue.shade700,
                          unselectedLabelColor: Colors.grey,
                          labelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                          indicatorColor: Colors.blue.shade700,
                          tabs: const [
                            Tab(
                                text: "Details",
                                icon: Icon(Icons.info_outline)),
                            Tab(text: "Activity", icon: Icon(Icons.history)),
                          ],
                        ),
                      ),

                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDetailsTab(),
                            _buildActivityTab(filteredLogs),
                          ],
                        ),
                      ),
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

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barcode Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'BARCODE ID',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    widget.user["barcodeId"],
                    style: GoogleFonts.orbitron(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(
                      'Copy ID',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.user["barcodeId"]),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Barcode ID copied!",
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.green.shade600,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 20),

          // Validity Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue.shade600),
                      const SizedBox(width: 12),
                      Text(
                        'Validity Period',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    "Valid From",
                    widget.user["validFrom"],
                    Icons.event,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    "Valid Until",
                    widget.user["validUntil"],
                    Icons.event_busy,
                    Colors.red,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 20),

          // Statistics Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart, color: Colors.blue.shade600),
                      const SizedBox(width: 12),
                      Text(
                        'Activity Statistics',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        getStatistics()["totalEntries"]!,
                        "Entries",
                        Colors.green,
                        Icons.login,
                      ),
                      _buildStatItem(
                        getStatistics()["totalExits"]!,
                        "Exits",
                        Colors.orange,
                        Icons.logout,
                      ),
                      _buildStatItem(
                        getStatistics()["totalDenied"]!,
                        "Denied",
                        Colors.red,
                        Icons.block,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildActivityTab(List<Map<String, dynamic>> filteredLogs) {
    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("All", "all"),
                const SizedBox(width: 8),
                _buildFilterChip("Entry", "entry"),
                const SizedBox(width: 8),
                _buildFilterChip("Exit", "exit"),
                const SizedBox(width: 8),
                _buildFilterChip("Denied", "denied"),
              ],
            ),
          ),
        ),

        // Logs List
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No activity logs",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
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
                              log["status"].toString().toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  formatTimestamp(log["timestamp"]),
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                                Text(
                                  "Device: ${log["deviceID"]}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => selectedFilter = value);
      },
      labelStyle: GoogleFonts.poppins(
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.grey.shade700,
      ),
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.blue.shade600,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
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

  Widget _buildStatItem(int value, String label, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
