import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final nameController = TextEditingController();
  final accessController = TextEditingController();

  final database = FirebaseDatabase.instance.ref("smart_door/users");

  void saveUser() async {
    final uuid = const Uuid();
    String barcodeId = uuid.v4(); // unique barcode

    String name = nameController.text.trim();
    String access = accessController.text.trim();

    if (name.isEmpty) return;

    String userKey = database.push().key!;

    await database.child(userKey).set({
      "name": name,
      "barcode_id": barcodeId,
      "access_level": access,
      "valid_from": DateTime.now().toIso8601String(),
      "valid_to":
          DateTime.now().add(const Duration(days: 365)).toIso8601String(),
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("User Added"),
        content: Text("Barcode ID:\n$barcodeId"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );

    nameController.clear();
    accessController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add User")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "User Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: accessController,
              decoration: const InputDecoration(
                labelText: "Access Level (employee/visitor/etc.)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: saveUser,
              child: const Text("Create User + Barcode"),
            ),
          ],
        ),
      ),
    );
  }
}
