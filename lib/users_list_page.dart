import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'user_details_page.dart';

class UsersListPage extends StatefulWidget {
  const UsersListPage({super.key});

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  final database = FirebaseDatabase.instance.ref("users");
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  bool isLoading = true;
  String searchQuery = "";
  String filterRole = "all";
  String filterStatus = "all";

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
        data.forEach((barcodeId, value) {
          loadedUsers.add({
            "barcodeId": barcodeId,
            "name": value["name"] ?? "N/A",
            "role": value["role"] ?? "N/A",
            "access": value["access"] ?? "allowed",
            "validFrom": value["validFrom"] ?? "N/A",
            "validUntil": value["validUntil"] ?? "N/A",
            "isActive": value["isActive"] ?? false,
          });
        });

        loadedUsers.sort((a, b) => a["name"].compareTo(b["name"]));

        if (mounted) {
          setState(() {
            users = loadedUsers;
            applyFilters();
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            users = [];
            filteredUsers = [];
            isLoading = false;
          });
        }
      }
    });
  }

  void applyFilters() {
    setState(() {
      filteredUsers = users.where((user) {
        bool matchesSearch = user["name"]
            .toString()
            .toLowerCase()
            .contains(searchQuery.toLowerCase());
        bool matchesRole = filterRole == "all" || user["role"] == filterRole;
        bool matchesStatus = filterStatus == "all" ||
            (filterStatus == "active" && user["isActive"]) ||
            (filterStatus == "inactive" && !user["isActive"]);

        return matchesSearch && matchesRole && matchesStatus;
      }).toList();
    });
  }

  void deleteUser(String barcodeId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Text(
              "Confirm Delete",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete user '$userName'? This action cannot be undone.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
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
              "Delete",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await database.child(barcodeId).remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "User deleted successfully",
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void toggleUserStatus(String barcodeId, bool currentStatus) async {
    await database.child(barcodeId).update({"isActive": !currentStatus});
  }

  void toggleUserAccess(String barcodeId, String currentAccess) async {
    String newAccess = currentAccess == "allowed" ? "denied" : "allowed";
    await database.child(barcodeId).update({"access": newAccess});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade700,
              Colors.green.shade500,
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
                                'All Users',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${filteredUsers.length} user(s) found',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search and Filters
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      onChanged: (value) {
                        searchQuery = value;
                        applyFilters();
                      },
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        hintStyle: GoogleFonts.poppins(),
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filters
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: filterRole,
                                isExpanded: true,
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                                items: [
                                  "all",
                                  "employee",
                                  "visitor",
                                  "manager",
                                  "contractor"
                                ].map((role) {
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Text(role.toUpperCase()),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    filterRole = value!;
                                    applyFilters();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: filterStatus,
                                isExpanded: true,
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                                items:
                                    ["all", "active", "inactive"].map((status) {
                                  return DropdownMenuItem(
                                    value: status,
                                    child: Text(status.toUpperCase()),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    filterStatus = value!;
                                    applyFilters();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Users List
              Expanded(
                child: isLoading
                    ? _buildShimmerLoading()
                    : filteredUsers.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return _buildUserCard(user, index);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    final isAllowed = user["access"] == "allowed";
    final isActive = user["isActive"];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailsPage(user: user),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Hero(
                tag: 'user_${user["barcodeId"]}',
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isActive && isAllowed
                          ? [Colors.green.shade400, Colors.green.shade700]
                          : [Colors.grey.shade300, Colors.grey.shade500],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      user["name"][0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user["name"],
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user["role"].toString().toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isAllowed
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user["access"].toString().toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isAllowed
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${user["barcodeId"]}',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isActive && isAllowed
                      ? Colors.green.shade500
                      : Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),

              // Menu
              PopupMenuButton(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: "view",
                    child: Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.blue.shade600),
                        const SizedBox(width: 12),
                        Text(
                          "View Details",
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "toggle_access",
                    child: Row(
                      children: [
                        Icon(
                          isAllowed ? Icons.block : Icons.check_circle,
                          color: isAllowed
                              ? Colors.red.shade600
                              : Colors.green.shade600,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isAllowed ? "Deny Access" : "Allow Access",
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "toggle",
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.person_off : Icons.person,
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isActive ? "Deactivate" : "Activate",
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "delete",
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red.shade600),
                        const SizedBox(width: 12),
                        Text(
                          "Delete",
                          style: GoogleFonts.poppins(
                            color: Colors.red.shade600,
                          ),
                        ),
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
                  } else if (value == "toggle_access") {
                    toggleUserAccess(user["barcodeId"], user["access"]);
                  } else if (value == "toggle") {
                    toggleUserStatus(user["barcodeId"], user["isActive"]);
                  } else if (value == "delete") {
                    deleteUser(user["barcodeId"], user["name"]);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 100 * index))
        .slideX(begin: 0.2, end: 0);
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            'No Users Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
