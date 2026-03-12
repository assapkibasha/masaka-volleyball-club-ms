import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/session/auth_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final token = ref.read(authControllerProvider).token!;
    final api = ref.read(apiClientProvider);
    final results = await Future.wait<dynamic>([
      api.getDashboardSummary(token),
      api.getRecentPayments(token),
    ]);

    return _DashboardData(
      summary: results[0] as Map<String, dynamic>,
      recentPayments: results[1] as List<dynamic>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        titleSpacing: 16,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sports_volleyball, color: AppColors.primaryBlack, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('MVCS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/notifications'),
            icon: const Badge(
              backgroundColor: Colors.red,
              smallSize: 8,
              child: Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
            ),
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryYellow,
              child: Text(
                _initials(auth.user?.fullName ?? 'MV'),
                style: const TextStyle(color: AppColors.primaryBlack, fontWeight: FontWeight.bold),
              ),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authControllerProvider).logout();
                if (!context.mounted) return;
                context.go('/login');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          final summary = snapshot.data!.summary;
          final recentPayments = snapshot.data!.recentPayments;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'MVCS',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlack),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back, ${auth.user?.fullName ?? 'Administrator'}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryCards(summary),
                  const SizedBox(height: 24),
                  _buildMonthlyProgress(summary),
                  const SizedBox(height: 24),
                  _buildRecentPayments(recentPayments),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/register-member'),
        backgroundColor: AppColors.primaryBlack,
        shape: const CircleBorder(side: BorderSide(color: AppColors.white, width: 4)),
        elevation: 4,
        child: const Icon(Icons.add, color: AppColors.primaryYellow, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildCard(
                icon: Icons.group,
                iconColor: AppColors.textSecondary,
                value: '${summary['totalMembers'] ?? 0}',
                label: 'TOTAL MEMBERS',
              ),
              const SizedBox(height: 12),
              _buildCard(
                icon: Icons.error,
                iconColor: Colors.red,
                value: '${summary['unpaidMembers'] ?? 0}',
                label: 'UNPAID',
                badgeText: _formattedMoney(summary['outstandingTotal']),
                badgeColor: Colors.red.shade100,
                badgeTextColor: Colors.red.shade700,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildCard(
                icon: Icons.check_circle,
                iconColor: Colors.green,
                value: '${summary['paidMembers'] ?? 0}',
                label: 'PAID THIS MONTH',
                badgeText: '${summary['progressPercent'] ?? 0}%',
                badgeColor: Colors.green.shade100,
                badgeTextColor: Colors.green.shade700,
              ),
              const SizedBox(height: 12),
              _buildCard(
                icon: Icons.account_balance_wallet,
                iconColor: AppColors.primaryBlack,
                value: _formattedMoney(summary['collectedTotal']),
                label: 'TOTAL COLLECTED',
                backgroundColor: AppColors.primaryYellow,
                textColor: AppColors.primaryBlack,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    Color backgroundColor = AppColors.white,
    Color textColor = AppColors.primaryBlack,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: backgroundColor == AppColors.white
            ? Border.all(color: AppColors.border)
            : Border.all(color: AppColors.primaryYellow.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                  child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeTextColor)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: backgroundColor == AppColors.white ? AppColors.textSecondary : textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyProgress(Map<String, dynamic> summary) {
    final progressPercent = (summary['progressPercent'] as int? ?? 0).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Monthly Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Target: ${_formattedMoney(summary['expectedTotal'])}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBlack),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collected: ${_formattedMoney(summary['collectedTotal'])}',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              Text('$progressPercent%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercent / 100,
              minHeight: 12,
              backgroundColor: AppColors.backgroundLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPayments(List<dynamic> recentPayments) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton(
              onPressed: () => context.go('/contributions'),
              child: const Text('VIEW ALL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: recentPayments.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No recent payments found.', style: TextStyle(color: AppColors.textSecondary)),
                )
              : Column(
                  children: [
                    for (var index = 0; index < recentPayments.length; index++) ...[
                      _buildPaymentItem(recentPayments[index] as Map<String, dynamic>),
                      if (index < recentPayments.length - 1) const Divider(height: 1, color: AppColors.divider),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final memberName = payment['memberName'] as String? ?? 'Unknown member';
    final date = DateTime.tryParse(payment['paymentDate'] as String? ?? '');
    final amount = _formattedMoney(payment['amountPaid']);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.backgroundLight,
                child: Text(_initials(memberName), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(memberName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    date == null ? 'Unknown date' : DateFormat('dd MMM, yyyy • hh:mm a').format(date.toLocal()),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text('PAID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formattedMoney(dynamic money) {
    if (money is Map<String, dynamic>) {
      return money['formatted'] as String? ?? 'RWF 0';
    }
    return 'RWF 0';
  }

  String _initials(String name) {
    final parts = name.split(' ').where((part) => part.isNotEmpty).take(2);
    final value = parts.map((part) => part[0].toUpperCase()).join();
    return value.isEmpty ? 'MV' : value;
  }
}

class _DashboardData {
  const _DashboardData({
    required this.summary,
    required this.recentPayments,
  });

  final Map<String, dynamic> summary;
  final List<dynamic> recentPayments;
}
