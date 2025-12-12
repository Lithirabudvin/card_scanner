import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'user_details_page.dart';

class UsersListPage extends StatefulWidget {
  const UsersListPage({super.key});

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  final database = FirebaseDatabase.instance.ref("users");
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  void loadUsers() async {
    setState(() => isLoading = true);

    database.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        List<Map<String, dynamic>> loadedUsers = [];
        data.forEach((key, value) {
          loadedUsers.add({
            "userId": key,
            "name": value["name"] ?? "N/A",
            "barcodeId": value["barcodeId"] ?? "N/A",
            "role": value["role"] ?? "N/A",
            "validFrom": value["validFrom"] ?? "N/A",
            "validUntil": value["validUntil"] ?? "N/A",
            "isActive": value["isActive"] ?? false,
          });
        });

        // Sort by name
        loadedUsers.sort((a, b) => a["name"].compareTo(b["name"]));

        if (mounted) {
          setState(() {
            users = loadedUsers;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            users = [];
            isLoading = false;
          });
        }
      }
    });
  }

  void deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete user '$userName'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await database.child(userId).remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User deleted successfully")),
        );
      }
    }
  }

  void toggleUserStatus(String userId, bool currentStatus) async {
    await database.child(userId).update({"isActive": !currentStatus});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registered Users"),
        elevation: 2,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No users registered yet"),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: users.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              user["isActive"] ? Colors.green : Colors.grey,
                          child: Text(
                            user["name"][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          user["name"],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${user["role"].toString().toUpperCase()} • ${user["isActive"] ? "Active" : "Inactive"}",
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: "view",
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline),
                                  SizedBox(width: 8),
                                  Text("View Details & Logs"),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: "toggle",
                              child: Row(
                                children: [
                                  Icon(user["isActive"]
                                      ? Icons.block
                                      : Icons.check_circle),
                                  const SizedBox(width: 8),
                                  Text(user["isActive"]
                                      ? "Deactivate"
                                      : "Activate"),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: "delete",
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text("Delete",
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == "view") {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserDetailsPage(user: user),
                                ),
                              );
                            } else if (value == "toggle") {
                              toggleUserStatus(
                                  user["userId"], user["isActive"]);
                            } else if (value == "delete") {
                              deleteUser(user["userId"], user["name"]);
                            }
                          },
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailsPage(user: user),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
