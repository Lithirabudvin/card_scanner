import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AllLogsPage extends StatefulWidget {
  const AllLogsPage({super.key});

  @override
  State<AllLogsPage> createState() => _AllLogsPageState();
}

class _AllLogsPageState extends State<AllLogsPage> {
  final logsDb = FirebaseDatabase.instance.ref("door_logs");
  List<Map<String, dynamic>> logs = [];
  bool isLoading = true;

  String selectedFilter = "all";
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  void loadLogs() async {
    setState(() => isLoading = true);

    logsDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        List<Map<String, dynamic>> loaded = [];

        data.forEach((key, value) {
          loaded.add({
            "logId": key,
            "userId": value["userId"] ?? "N/A",
            "userName": value["userName"] ?? "N/A",
            "barcodeId": value["barcodeId"] ?? "N/A",
            "timestamp": value["timestamp"] ?? 0,
            "event": value["event"] ?? "N/A",
            "date": value["date"] ?? "N/A",
            "time": value["time"] ?? "N/A",
            "status": value["status"] ?? "N/A",
          });
        });

        // Sort by timestamp (most recent first)
        loaded.sort((a, b) => b["timestamp"].compareTo(a["timestamp"]));

        if (mounted) {
          setState(() {
            logs = loaded;
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

    // Filter by event type
    if (selectedFilter == "entrance") {
      filtered = filtered.where((log) => log["event"] == "entrance").toList();
    } else if (selectedFilter == "exit") {
      filtered = filtered.where((log) => log["event"] == "exit").toList();
    } else if (selectedFilter == "denied") {
      filtered =
          filtered.where((log) => log["event"] == "access_denied").toList();
    }

    // Filter by date
    if (selectedDate != null) {
      String dateStr =
          "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
      filtered = filtered.where((log) => log["date"] == dateStr).toList();
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

  String formatTimestamp(int timestamp) {
    if (timestamp == 0) return "N/A";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
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

  Map<String, int> getStatistics() {
    int totalEntries = logs.where((log) => log["event"] == "entrance").length;
    int totalExits = logs.where((log) => log["event"] == "exit").length;
    int totalDenied =
        logs.where((log) => log["event"] == "access_denied").length;

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
            onPressed: loadLogs,
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
                      const Text("Filter: ",
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
                        label: const Text("Entrance"),
                        selected: selectedFilter == "entrance",
                        onSelected: (_) =>
                            setState(() => selectedFilter = "entrance"),
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
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
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
                                "${log["event"].toString().toUpperCase().replaceAll("_", " ")} - ${log["userName"]}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                      "Date: ${log["date"]} at ${log["time"]}"),
                                  if (log["event"] == "access_denied")
                                    Text(
                                        "Barcode: ${log["barcodeId"].length > 20 ? log["barcodeId"].substring(0, 20) + "..." : log["barcodeId"]}"),
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
                                          _buildDetailRow(
                                              "User", log["userName"]),
                                          _buildDetailRow(
                                              "User ID", log["userId"]),
                                          _buildDetailRow(
                                              "Barcode ID", log["barcodeId"]),
                                          _buildDetailRow(
                                              "Event", log["event"]),
                                          _buildDetailRow("Date", log["date"]),
                                          _buildDetailRow("Time", log["time"]),
                                          _buildDetailRow(
                                              "Status", log["status"]),
                                          _buildDetailRow(
                                              "Full Timestamp",
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
