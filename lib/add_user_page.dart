import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final nameController = TextEditingController();
  final database = FirebaseDatabase.instance.ref("users");

  String selectedRole = "employee";
  DateTime validFrom = DateTime.now();
  DateTime validUntil = DateTime.now().add(const Duration(days: 365));
  bool isActive = true;
  bool isLoading = false;

  final roles = ["employee", "visitor", "manager", "contractor"];

  void saveUser() async {
    String name = nameController.text.trim();

    if (name.isEmpty) {
      _showSnackBar("Please enter user name");
      return;
    }

    setState(() => isLoading = true);

    try {
      final uuid = const Uuid();
      String barcodeId = uuid.v4();
      String userKey = database.push().key!;

      await database.child(userKey).set({
        "name": name,
        "barcodeId": barcodeId,
        "validFrom": validFrom.toString().substring(0, 16),
        "validUntil": validUntil.toString().substring(0, 16),
        "role": selectedRole,
        "isActive": isActive,
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("✓ User Created Successfully"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Name: $name"),
              const SizedBox(height: 8),
              Text("Role: $selectedRole"),
              const SizedBox(height: 8),
              const Text("Barcode ID:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(
                barcodeId,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text("Copy Barcode ID"),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: barcodeId));
                  _showSnackBar("Barcode ID copied to clipboard");
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        ),
      );

      nameController.clear();
      setState(() {
        selectedRole = "employee";
        validFrom = DateTime.now();
        validUntil = DateTime.now().add(const Duration(days: 365));
        isActive = true;
      });
    } catch (e) {
      _showSnackBar("Error: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? validFrom : validUntil,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          validFrom = picked;
        } else {
          validUntil = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New User"),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "User Name",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: "Role / Access Level",
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
              items: roles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedRole = value!);
              },
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Validity Period",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text("Valid From"),
                      subtitle: Text(validFrom.toString().substring(0, 16)),
                      onTap: () => _selectDate(context, true),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: const Text("Valid Until"),
                      subtitle: Text(validUntil.toString().substring(0, 16)),
                      onTap: () => _selectDate(context, false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text("Active Status"),
              subtitle: Text(isActive ? "User is active" : "User is inactive"),
              value: isActive,
              onChanged: (value) {
                setState(() => isActive = value);
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: isLoading ? null : saveUser,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(isLoading ? "Creating..." : "Create User + Barcode"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }
}
