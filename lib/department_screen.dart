import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:qms_feedback/constants.dart';
import 'package:qms_feedback/department.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qms_feedback/feedback_screen.dart';

Future<List<Department>> _fetchDepartments() async {
  try {
    final response = await http
        .get(Uri.parse('$baseUrl/departments'))
        .timeout(const Duration(seconds: 10)); // Add timeout

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final departmentsList = data['departments'] as List;
      return departmentsList.map((dept) => Department.fromJson(dept)).toList();
    } else {
      throw _handleStatusCode(response.statusCode);
    }
  } on SocketException {
    throw 'No internet connection. Please check your network settings.';
  } on TimeoutException {
    throw 'Request timed out. Please try again.';
  } on http.ClientException catch (e) {
    throw 'Network error: ${e.message}';
  } on FormatException {
    throw 'Data format error. Please contact support.';
  } catch (e) {
    throw 'An unexpected error occurred: ${e.toString()}';
  }
}

String _handleStatusCode(int statusCode) {
  switch (statusCode) {
    case 400:
      return 'Bad request';
    case 401:
      return 'Unauthorized';
    case 403:
      return 'Forbidden';
    case 404:
      return 'Department not found';
    case 500:
      return 'Internal server error';
    case 503:
      return 'Service unavailable';
    default:
      return 'Failed to load departments (Status code: $statusCode)';
  }
}

class DepartmentSelectionPage extends StatefulWidget {
  const DepartmentSelectionPage({Key? key}) : super(key: key);

  @override
  _DepartmentSelectionPageState createState() =>
      _DepartmentSelectionPageState();
}

class _DepartmentSelectionPageState extends State<DepartmentSelectionPage> {
  late Future<List<Department>> futureDepartments;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    futureDepartments = _fetchDepartments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Department'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Department>>(
          future: futureDepartments,
          builder: (context, snapshot) {
            // UI/UX Principle: Provide clear feedback for different states
            if (snapshot.connectionState == ConnectionState.waiting &&
                !_isLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              // UI/UX Principle: Error state with retry option
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.red),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          futureDepartments = _fetchDepartments();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            } else if (snapshot.hasData) {
              final departments = snapshot.data!;

              // UI/UX Principle: Responsive grid layout that adapts to screen size
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: departments.length,
                itemBuilder: (context, index) {
                  final department = departments[index];
                  return _buildDepartmentCard(department);
                },
              );
            } else {
              return const Center(child: Text('No departments found'));
            }
          },
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(Department department) {
    debugPrint(department.logo.toString());
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // UI/UX Principle: Visual feedback on tap
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToFeedbackPage(department),
        splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
        highlightColor: Theme.of(context).primaryColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // UI/UX Principle: Consistent image sizing with placeholder
              SizedBox(
                height: 80,
                width: 80,
                child:
                    department.logo != null
                        ? CachedNetworkImage(
                          imageUrl: '$baseUrlbase/${department.logo}',
                          placeholder:
                              (context, url) => const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                          errorWidget:
                              (context, url, error) =>
                                  const Icon(Icons.business, size: 48),
                          fit: BoxFit.contain,
                        )
                        : const Icon(Icons.business, size: 48),
              ),
              const SizedBox(height: 16),
              // UI/UX Principle: Text hierarchy with proper typography
              Text(
                department.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (department.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  department.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToFeedbackPage(Department department) async {
    setState(() => _isLoading = true);

    // UI/UX Principle: Smooth transition with loading indicator
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                FeedbackHomePage(department: department),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    setState(() => _isLoading = false);
  }
}
