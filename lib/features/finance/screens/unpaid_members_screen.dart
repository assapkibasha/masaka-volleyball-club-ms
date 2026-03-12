import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

class UnpaidMembersScreen extends ConsumerStatefulWidget {
  const UnpaidMembersScreen({super.key});

  @override
  ConsumerState<UnpaidMembersScreen> createState() => _UnpaidMembersScreenState();
}

class _UnpaidMembersScreenState extends ConsumerState<UnpaidMembersScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() {
    return ref.read(apiClientProvider).getUnpaidMembers(ref.read(authControllerProvider).token!);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _sendReminder(Map<String, dynamic> member) async {
    try {
      await ref.read(apiClientProvider).sendReminder(
            token: ref.read(authControllerProvider).token!,
            memberIds: [member['memberId'] as String],
            title: 'Payment Reminder',
            message: 'Your monthly contribution is overdue. Please clear the outstanding balance.',
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder sent to ${member['fullName']}.')),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlack),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'UNPAID MEMBERS',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.primaryBlack),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.primaryBlack), onPressed: _refresh),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.border, height: 1.0),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
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

          final members = snapshot.data ?? const [];
          final outstandingTotal = members.fold<int>(
            0,
            (sum, item) => sum + (((item as Map<String, dynamic>)['amountDue'] as Map<String, dynamic>?)?['amount'] as int? ?? 0),
          );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlack,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('UNPAID MEMBERS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
                              const SizedBox(height: 8),
                              Text('${members.length}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text('Current month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryYellow)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primaryYellow,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: AppColors.primaryYellow.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('OUTSTANDING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0x99000000), letterSpacing: 1)),
                              const SizedBox(height: 8),
                              Text('RWF $outstandingTotal', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryBlack)),
                              const SizedBox(height: 4),
                              const Text('Current period', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('DEFAULTING MEMBERS LIST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primaryBlack, letterSpacing: -0.5)),
                      Text('Sorted by overdue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (members.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No unpaid members found.', style: TextStyle(color: AppColors.textSecondary))),
                  )
                else
                  ...members.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: _buildMemberCard(item as Map<String, dynamic>),
                      )),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final amountDue = (member['amountDue'] as Map<String, dynamic>?)?['formatted'] as String? ?? 'RWF 0';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.backgroundLight,
                  child: Text(
                    _initials(member['fullName'] as String? ?? ''),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member['fullName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                Text(
                                  '${member['role'] ?? '-'} • ${member['team'] ?? '-'}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text('UNPAID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.red.shade700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('AMOUNT DUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1)),
                              Text(amountDue, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryBlack)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1)),
                              Text(
                                '${member['daysOverdue'] ?? 0} days overdue',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ElevatedButton.icon(
              onPressed: () => _sendReminder(member),
              icon: const Icon(Icons.send, size: 18, color: AppColors.primaryBlack),
              label: const Text('SEND REMINDER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13, color: AppColors.primaryBlack)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryYellow,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.split(' ').where((part) => part.isNotEmpty).take(2);
    final text = parts.map((part) => part[0].toUpperCase()).join();
    return text.isEmpty ? 'MV' : text;
  }
}
