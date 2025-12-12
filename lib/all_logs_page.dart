import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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

        // Loop through all devices
        data.forEach((deviceId, deviceLogs) {
          devices.add(deviceId);

          if (deviceLogs is Map) {
            // Loop through logs for this device
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

        // Sort by timestamp (most recent first)
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

    // Filter by status
    if (selectedFilter == "entry") {
      filtered = filtered.where((log) => log["status"] == "entry").toList();
    } else if (selectedFilter == "exit") {
      filtered = filtered.where((log) => log["status"] == "exit").toList();
    } else if (selectedFilter == "denied") {
      filtered = filtered.where((log) => log["status"] == "denied").toList();
    }

    // Filter by device
    if (selectedDevice != "all") {
      filtered =
          filtered.where((log) => log["deviceID"] == selectedDevice).toList();
    }

    // Filter by date
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
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
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
      "totalLogs": logs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = getStatistics();
    final filteredLogs = getFilteredLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Door Logs"),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              loadUsers();
              loadLogs();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                      "Entries", stats["totalEntries"]!, Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                      "Exits", stats["totalExits"]!, Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                      "Denied", stats["totalDenied"]!, Colors.red),
                ),
              ],
            ),
          ),

          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text("Status: ",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("All"),
                        selected: selectedFilter == "all",
                        onSelected: (_) =>
                            setState(() => selectedFilter = "all"),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("Entry"),
                        selected: selectedFilter == "entry",
                        onSelected: (_) =>
                            setState(() => selectedFilter = "entry"),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("Exit"),
                        selected: selectedFilter == "exit",
                        onSelected: (_) =>
                            setState(() => selectedFilter = "exit"),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("Denied"),
                        selected: selectedFilter == "denied",
                        onSelected: (_) =>
                            setState(() => selectedFilter = "denied"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Device: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text("All"),
                              selected: selectedDevice == "all",
                              onSelected: (_) =>
                                  setState(() => selectedDevice = "all"),
                            ),
                            ...deviceIds.map((deviceId) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ChoiceChip(
                                    label: Text(deviceId),
                                    selected: selectedDevice == deviceId,
                                    onSelected: (_) => setState(
                                        () => selectedDevice = deviceId),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Date: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(selectedDate != null
                          ? "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}"
                          : "Select Date"),
                      onPressed: () => selectDate(context),
                    ),
                    if (selectedDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: clearDateFilter,
                      ),
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
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text("No logs found"),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredLogs.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          final userName = getUserName(log["barcode"]);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
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
                                "${log["status"].toString().toUpperCase()} - $userName",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text("Device: ${log["deviceID"]}"),
                                  Text(
                                      "Time: ${formatTimestamp(log["timestamp"])}"),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.info_outline),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Log Details"),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildDetailRow(
                                              "Log ID", log["logId"]),
                                          _buildDetailRow("User", userName),
                                          _buildDetailRow(
                                              "Barcode", log["barcode"]),
                                          _buildDetailRow(
                                              "Status", log["status"]),
                                          _buildDetailRow(
                                              "Device", log["deviceID"]),
                                          _buildDetailRow(
                                              "Timestamp",
                                              formatTimestamp(
                                                  log["timestamp"])),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text("Close"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value.toString(),
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
