import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qms_feedback/constants.dart';
import 'package:qms_feedback/department.dart';

class FeedbackHomePage extends StatefulWidget {
  final Department department;
  const FeedbackHomePage({super.key, required this.department});

  @override
  State<FeedbackHomePage> createState() => _FeedbackHomePageState();
}

class _FeedbackHomePageState extends State<FeedbackHomePage> {
  late Future<List<CompletedService>> _completedServicesFuture;
  bool _isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !_isLoading) {
        _loadData();
      }
    });
  }

  void _loadData() {
    if (mounted) {
      setState(() {
        _completedServicesFuture = _fetchCompletedServices(
          widget.department.id,
        );
      });
    }
  }

  Future<List<CompletedService>> _fetchCompletedServices(
    int departmentId,
  ) async {
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/departments/$departmentId/feedback-tokens'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final tokens = data['tokens'] as List;
          return tokens.map((token) {
            return CompletedService(
              ticketNumber: token['token_no'] ?? 'N/A',
              counterName: token['user']?['name'] ?? 'Counter N/A',
              serviceName: token['service']?['name'] ?? 'Service N/A',
              departmentName: token['department']?['name'] ?? 'Department N/A',
            );
          }).toList();
        } else {
          throw Exception('Failed to load completed services');
        }
      } else {
        throw Exception(
          'Failed to load completed services: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching services: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Department header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${widget.department.name} Department",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _loadData,
                  tooltip: 'Refresh',
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Completed Services',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          // List of completed services
          Expanded(
            child: FutureBuilder<List<CompletedService>>(
              future: _completedServicesFuture,
              builder: (context, snapshot) {
                if (_isLoading &&
                    snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
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
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasData) {
                  final completedServices = snapshot.data!;
                  if (completedServices.isEmpty) {
                    return const Center(
                      child: Text('No completed services found'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _loadData(),
                    child: ListView.builder(
                      itemCount: completedServices.length,
                      itemBuilder: (context, index) {
                        final service = completedServices[index];
                        return ServiceCard(
                          service: service,
                          onTap: () => _showFeedbackDialog(context, service),
                        );
                      },
                    ),
                  );
                } else {
                  return const Center(child: Text('No data available'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Color getColor(num rating) {
    if (rating == 1) return Colors.red;
    if (rating == 2) return Colors.orange;
    if (rating == 3) return Colors.yellow;
    if (rating == 5) return Colors.green;
    if (rating == 4) return Colors.lightGreen;
    return Colors.grey;
  }

  void _showFeedbackDialog(BuildContext context, CompletedService service) {
    int selectedRating = 0;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    Future<void> submitFeedback() async {
      if (selectedRating == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a rating')));
        return;
      }

      setState(() => isSubmitting = true);
      var message = '';

      try {
        // debugPrint

        final body = json.encode({
          'rate': selectedRating,
          'token_number': service.ticketNumber,
          'comment': commentController.text,
        });
        debugPrint('Submitting feedback: $body');
        final response = await http
            .post(
              Uri.parse('$baseUrl/feedbacks'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            if (mounted) {
              Navigator.pop(context);
              _showThankYouMessage(context);
              _loadData(); // Refresh the list after submission
            }
          } else {
            throw Exception(
              responseData['message'] ?? 'Failed to submit feedback',
            );
          }
        } else {
          debugPrint(response.body.toString());
          throw Exception('Failed to submit feedback: ${response.statusCode}');
        }
      } on SocketException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection')),
          );
        }
      } on TimeoutException {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Request timed out')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
          Navigator.pop(context); // Close the dialog on errors
        }
      } finally {
        _fetchCompletedServices(widget.department.id);
        if (mounted) {
          setState(() => isSubmitting = false);
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Service Feedback'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 550,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ticket: ${service.ticketNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Service: ${service.serviceName}'),
                        const SizedBox(height: 8),
                        Text('Counter: ${service.counterName}'),
                        const SizedBox(height: 20),
                        const Text(
                          'How would you rate this service?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(5, (index) {
                            int rating = index + 1;
                            bool isSelected = selectedRating == rating;

                            return ChoiceChip(
                              backgroundColor: getColor(rating),
                              label: Text(
                                rating.toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 36,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.black54,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: getColor(rating),
                              onSelected: (_) {
                                setState(() {
                                  selectedRating = rating;
                                });
                              },
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Additional comments (optional):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: commentController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Enter your comments here...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              actions: [
                SizedBox(
                  width: 120,
                  height: 48,
                  child: TextButton(
                    onPressed:
                        isSubmitting ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  height: 48,
                  child: ElevatedButton(
                    onPressed:
                        isSubmitting || selectedRating == 0
                            ? null
                            : submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child:
                        isSubmitting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showThankYouMessage(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });

        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 48),
              SizedBox(height: 16),
              Text(
                'Thank you for your feedback!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class ServiceCard extends StatelessWidget {
  final CompletedService service;
  final VoidCallback onTap;

  const ServiceCard({super.key, required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    service.ticketNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onTap,
                        child: const Text('Give Feedback'),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          service.counterName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${service.departmentName} => ${service.serviceName}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class CompletedService {
  final String ticketNumber;
  final String counterName;
  final String serviceName;
  final String departmentName;

  CompletedService({
    required this.ticketNumber,
    required this.counterName,
    required this.serviceName,
    required this.departmentName,
  });
}
