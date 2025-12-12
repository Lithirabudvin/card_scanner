import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final database = FirebaseDatabase.instance.ref("logs");
  List<Map<String, dynamic>> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  void loadLogs() async {
    setState(() => isLoading = true);

    database.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        List<Map<String, dynamic>> loadedLogs = [];
        data.forEach((key, value) {
          loadedLogs.add({
            "logId": key,
            "userId": value["userId"] ?? "N/A",
            "barcodeId": value["barcodeId"] ?? "N/A",
            "time": value["time"] ?? 0,
            "event": value["event"] ?? "N/A",
          });
        });

        // Sort by time (most recent first)
        loadedLogs.sort((a, b) => b["time"].compareTo(a["time"]));

        if (mounted) {
          setState(() {
            logs = loadedLogs;
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

  String formatTimestamp(int timestamp) {
    if (timestamp == 0) return "N/A";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
  }

  IconData getEventIcon(String event) {
    if (event.contains("unlock")) return Icons.lock_open;
    if (event.contains("lock")) return Icons.lock;
    if (event.contains("denied")) return Icons.block;
    if (event.contains("request")) return Icons.notifications;
    return Icons.event;
  }

  Color getEventColor(String event) {
    if (event.contains("unlock")) return Colors.green;
    if (event.contains("lock")) return Colors.orange;
    if (event.contains("denied")) return Colors.red;
    if (event.contains("request")) return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Access Logs"),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadLogs,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : logs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No access logs yet"),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final log = logs[index];
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
                          log["event"]
                              .toString()
                              .toUpperCase()
                              .replaceAll("_", " "),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text("User ID: ${log["userId"]}"),
                            Text("Time: ${formatTimestamp(log["time"])}"),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow("Log ID", log["logId"]),
                                    _buildDetailRow("User ID", log["userId"]),
                                    _buildDetailRow(
                                        "Barcode ID", log["barcodeId"]),
                                    _buildDetailRow("Event", log["event"]),
                                    _buildDetailRow("Timestamp",
                                        formatTimestamp(log["time"])),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
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
