import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class AllLogsPage extends StatefulWidget {
  const AllLogsPage({super.key});

  @override
  State<AllLogsPage> createState() => _AllLogsPageState();
}

class _AllLogsPageState extends State<AllLogsPage> {
  final logsDb = FirebaseDatabase.instance.ref("logs");
  final usersDb = FirebaseDatabase.instance.ref("users");

  List<Map<String, dynamic>> logs = [];
  Map<String, String> barcodeToName = {};
  bool isLoading = true;

  String selectedFilter = "all";
  String selectedDevice = "all";
  DateTime? selectedDate;

  Set<String> deviceIds = {};

  @override
  void initState() {
    super.initState();
    loadUsers();
    loadLogs();
  }

  void loadUsers() async {
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

  void loadLogs() async {
    setState(() => isLoading = true);

    logsDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        List<Map<String, dynamic>> loaded = [];
        Set<String> devices = {};

        data.forEach((deviceId, deviceLogs) {
          devices.add(deviceId);

          if (deviceLogs is Map) {
            deviceLogs.forEach((logId, logData) {
              loaded.add({
                "logId": logId,
                "barcode": logData["barcode"] ?? "N/A",
                "timestamp": logData["timestamp"] ?? "N/A",
                "status": logData["status"] ?? "N/A",
                "deviceID": logData["deviceID"] ?? deviceId,
              });
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
            logs = loaded;
            deviceIds = devices;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            logs = [];
            isLoading = false;
          });
        }
      }
    });
  }

  List<Map<String, dynamic>> getFilteredLogs() {
    List<Map<String, dynamic>> filtered = logs;

    if (selectedFilter != "all") {
      filtered =
          filtered.where((log) => log["status"] == selectedFilter).toList();
    }

    if (selectedDevice != "all") {
      filtered =
          filtered.where((log) => log["deviceID"] == selectedDevice).toList();
    }

    if (selectedDate != null) {
      filtered = filtered.where((log) {
        try {
          DateTime logDate = DateTime.parse(log["timestamp"]);
          return logDate.year == selectedDate!.year &&
              logDate.month == selectedDate!.month &&
              logDate.day == selectedDate!.day;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    return filtered;
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade600,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void clearDateFilter() {
    setState(() {
      selectedDate = null;
    });
  }

  String formatTimestamp(String timestamp) {
    try {
      DateTime dt = DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy HH:mm').format(dt);
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

  Map<String, int> getStatistics() {
    int totalEntries = logs.where((log) => log["status"] == "entry").length;
    int totalExits = logs.where((log) => log["status"] == "exit").length;
    int totalDenied = logs.where((log) => log["status"] == "denied").length;

    return {
      "totalEntries": totalEntries,
      "totalExits": totalExits,
      "totalDenied": totalDenied,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = getStatistics();
    final filteredLogs = getFilteredLogs();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade700,
              Colors.orange.shade500,
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
                                'Door Logs',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${filteredLogs.length} log(s) found',
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
                          onPressed: () {
                            loadUsers();
                            loadLogs();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Statistics Cards
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatCard(
                        "Entries",
                        stats["totalEntries"]!,
                        Colors.green,
                        Icons.login,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMiniStatCard(
                        "Exits",
                        stats["totalExits"]!,
                        Colors.orange,
                        Icons.logout,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMiniStatCard(
                        "Denied",
                        stats["totalDenied"]!,
                        Colors.red,
                        Icons.block,
                      ),
                    ),
                  ],
                ),
              ),

              // Filters
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    // Status Filter
                    SingleChildScrollView(
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
                    const SizedBox(height: 12),

                    // Device & Date Filter
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedDevice,
                                isExpanded: true,
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                                items: ["all", ...deviceIds].map((device) {
                                  return DropdownMenuItem(
                                    value: device,
                                    child: Text(
                                      device == "all" ? "All Devices" : device,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => selectedDevice = value!);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => selectDate(context),
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            selectedDate != null
                                ? DateFormat('MMM dd').format(selectedDate!)
                                : "Date",
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.grey.shade800,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        if (selectedDate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: clearDateFilter,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
                                  "No logs found",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredLogs.length,
                            padding: const EdgeInsets.all(20),
                            itemBuilder: (context, index) {
                              final log = filteredLogs[index];
                              final userName = getUserName(log["barcode"]);

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) =>
                                          _buildLogDetailDialog(log, userName),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                getStatusColor(log["status"])
                                                    .withOpacity(0.7),
                                                getStatusColor(log["status"]),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            getStatusIcon(log["status"]),
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                userName,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: getStatusColor(
                                                              log["status"])
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      log["status"]
                                                          .toString()
                                                          .toUpperCase(),
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: getStatusColor(
                                                            log["status"]),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.device_hub,
                                                    size: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    log["deviceID"],
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    formatTimestamp(
                                                        log["timestamp"]),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                                  .animate()
                                  .fadeIn(
                                      delay: Duration(milliseconds: 50 * index))
                                  .slideX(begin: 0.2, end: 0);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatCard(
    String label,
    int value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
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
      backgroundColor: Colors.white,
      selectedColor: Colors.orange.shade600,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildLogDetailDialog(Map<String, dynamic> log, String userName) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: getStatusColor(log["status"]).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    getStatusIcon(log["status"]),
                    color: getStatusColor(log["status"]),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "Log Details",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow("User", userName),
            _buildDetailRow("Barcode", log["barcode"]),
            _buildDetailRow("Status", log["status"].toString().toUpperCase()),
            _buildDetailRow("Device", log["deviceID"]),
            _buildDetailRow("Timestamp", formatTimestamp(log["timestamp"])),
            _buildDetailRow("Log ID", log["logId"]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Close",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
