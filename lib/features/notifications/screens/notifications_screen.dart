import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

enum NotificationStatus { delivered, failed, pending }

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _searchController = TextEditingController();
  int _selectedTab = 0;
  final List<String> _tabs = ['All', 'Sent', 'Failed', 'Pending'];
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _load() {
    final token = ref.read(authControllerProvider).token!;
    final status = switch (_selectedTab) {
      1 => 'delivered',
      2 => 'failed',
      3 => 'pending',
      _ => null,
    };

    return ref.read(apiClientProvider).getNotifications(
          token,
          status: status,
          search: _searchController.text.trim(),
        );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _handleNotificationAction(Map<String, dynamic> item) async {
    final status = item['status'] as String? ?? '';
    final api = ref.read(apiClientProvider);
    final token = ref.read(authControllerProvider).token!;

    try {
      if (status == 'failed') {
        await api.resendNotification(token, item['id'] as String);
      } else if (status == 'pending') {
        await api.cancelNotification(token, item['id'] as String);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'failed' ? 'Notification resent.' : 'Pending notification cancelled.')),
      );
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F0),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlack),
                        onPressed: () => context.pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'NOTIFICATIONS',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlack, letterSpacing: 0.5),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.primaryBlack),
                        onPressed: _refresh,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _refresh(),
                    decoration: InputDecoration(
                      hintText: 'Search members or messages...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(_tabs.length, (index) {
                    final isSelected = index == _selectedTab;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = index;
                            _future = _load();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 12, top: 4),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: isSelected ? AppColors.primaryYellow : Colors.transparent, width: 2)),
                          ),
                          child: Text(
                            _tabs[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                Container(height: 1, color: AppColors.border),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(snapshot.error.toString(), textAlign: TextAlign.center),
                    ),
                  );
                }

                final notifications = snapshot.data ?? const [];
                if (notifications.isEmpty) {
                  return const Center(
                    child: Text('No notifications found.', style: TextStyle(color: AppColors.textSecondary)),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildNotificationCard(notifications[index] as Map<String, dynamic>),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: -1),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final status = item['status'] as String? ?? 'pending';
    final (Color statusBg, Color statusText, String statusLabel) = switch (status) {
      'delivered' => (Colors.green.withValues(alpha: 0.1), Colors.green.shade700, 'Delivered'),
      'failed' => (Colors.red.withValues(alpha: 0.1), Colors.red.shade700, 'Failed'),
      _ => (Colors.orange.withValues(alpha: 0.1), Colors.orange.shade700, 'Pending'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['memberName'] as String? ?? 'Unknown member', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryBlack)),
                  Text(
                    (item['channel'] as String? ?? 'system').toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                child: Text(statusLabel.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusText)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(item['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primaryBlack)),
          const SizedBox(height: 4),
          Text(item['message'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(_formatDate(item['sentAt'] as String? ?? item['scheduledFor'] as String?), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              if (status == 'failed')
                ElevatedButton(
                  onPressed: () => _handleNotificationAction(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: AppColors.primaryBlack,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: const Text('Resend', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              if (status == 'pending')
                OutlinedButton(
                  onPressed: () => _handleNotificationAction(item),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.primaryBlack,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value);
    if (parsed == null) {
      return 'Unknown time';
    }
    return DateFormat('dd MMM yyyy • hh:mm a').format(parsed.toLocal());
  }
}
