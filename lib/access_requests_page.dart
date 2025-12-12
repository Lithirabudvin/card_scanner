import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AccessRequestsPage extends StatefulWidget {
  const AccessRequestsPage({super.key});

  @override
  State<AccessRequestsPage> createState() => _AccessRequestsPageState();
}

class _AccessRequestsPageState extends State<AccessRequestsPage> {
  final requestsDb = FirebaseDatabase.instance.ref("access_requests");
  final usersDb = FirebaseDatabase.instance.ref("users");
  final doorDb = FirebaseDatabase.instance.ref("door_control");
  final logsDb = FirebaseDatabase.instance.ref("logs");

  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  void loadRequests() async {
    setState(() => isLoading = true);

    requestsDb.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        List<Map<String, dynamic>> loadedRequests = [];
        data.forEach((key, value) {
          loadedRequests.add({
            "requestId": key,
            "barcodeId": value["barcodeId"] ?? "N/A",
            "requestTime": value["requestTime"] ?? 0,
            "status": value["status"] ?? "pending",
          });
        });

        // Sort by time (most recent first)
        loadedRequests
            .sort((a, b) => b["requestTime"].compareTo(a["requestTime"]));

        if (mounted) {
          setState(() {
            requests = loadedRequests;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            requests = [];
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
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Future<Map<String, dynamic>?> getUserByBarcodeId(String barcodeId) async {
    final snapshot = await usersDb.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        if (entry.value["barcodeId"] == barcodeId) {
          return {
            "userId": entry.key,
            "name": entry.value["name"],
            "role": entry.value["role"],
            "isActive": entry.value["isActive"],
            "validFrom": entry.value["validFrom"],
            "validUntil": entry.value["validUntil"],
          };
        }
      }
    }
    return null;
  }

  void handleRequest(String requestId, String barcodeId, bool approve) async {
    final user = await getUserByBarcodeId(barcodeId);

    if (user == null) {
      _showSnackBar("User not found");
      await requestsDb.child(requestId).update({"status": "denied"});
      return;
    }

    if (!user["isActive"]) {
      _showSnackBar("User is inactive");
      await requestsDb.child(requestId).update({"status": "denied"});
      await _logAccess(user["userId"], barcodeId, "access_denied_inactive");
      return;
    }

    if (approve) {
      // Unlock door
      await doorDb.update({
        "lockState": "unlocked",
        "lastUnlockUser": user["userId"],
        "lastUnlockTime": DateTime.now().millisecondsSinceEpoch,
      });

      // Update request status
      await requestsDb.child(requestId).update({"status": "approved"});

      // Log the access
      await _logAccess(user["userId"], barcodeId, "door_unlocked");

      _showSnackBar("Access granted to ${user["name"]}");

      // Auto-lock after 5 seconds (simulated)
      Future.delayed(const Duration(seconds: 5), () {
        doorDb.update({"lockState": "locked"});
      });
    } else {
      await requestsDb.child(requestId).update({"status": "denied"});
      await _logAccess(user["userId"], barcodeId, "access_denied_manual");
      _showSnackBar("Access denied");
    }
  }

  Future<void> _logAccess(String userId, String barcodeId, String event) async {
    String logKey = logsDb.push().key!;
    await logsDb.child(logKey).set({
      "userId": userId,
      "barcodeId": barcodeId,
      "time": DateTime.now().millisecondsSinceEpoch,
      "event": event,
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "approved":
        return Colors.green;
      case "denied":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Access Requests"),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadRequests,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pending_actions, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No access requests"),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: requests.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final isPending = request["status"] == "pending";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: getStatusColor(request["status"]),
                          child: Icon(
                            isPending
                                ? Icons.pending
                                : request["status"] == "approved"
                                    ? Icons.check
                                    : Icons.close,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          request["status"].toString().toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                                "Barcode: ${request["barcodeId"].substring(0, 20)}..."),
                            Text(
                                "Time: ${formatTimestamp(request["requestTime"])}"),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: isPending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check,
                                        color: Colors.green),
                                    onPressed: () => handleRequest(
                                      request["requestId"],
                                      request["barcodeId"],
                                      true,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    onPressed: () => handleRequest(
                                      request["requestId"],
                                      request["barcodeId"],
                                      false,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
