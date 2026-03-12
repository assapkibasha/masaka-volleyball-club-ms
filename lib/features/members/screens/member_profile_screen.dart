import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/auth_controller.dart';
import '../../../../core/theme/app_colors.dart';

class MemberProfileScreen extends ConsumerStatefulWidget {
  const MemberProfileScreen({
    required this.memberId,
    super.key,
  });

  final String memberId;

  @override
  ConsumerState<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends ConsumerState<MemberProfileScreen> {
  late Future<_MemberProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MemberProfileData> _load() async {
    final token = ref.read(authControllerProvider).token!;
    final api = ref.read(apiClientProvider);

    final member = await api.getMember(token, widget.memberId);
    final contributions = await api.getMemberContributions(token, widget.memberId);

    return _MemberProfileData(
      member: member,
      contributions: contributions,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _recordPayment(Map<String, dynamic> member) async {
    final amountController = TextEditingController(text: '${member['monthlyContributionAmount'] ?? 0}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount paid'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(apiClientProvider).recordPayment(
            ref.read(authControllerProvider).token!,
            {
              'memberId': member['id'],
              'amountPaid': int.tryParse(amountController.text.trim()) ?? 0,
            },
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully.')),
      );
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _sendReminder(Map<String, dynamic> member) async {
    try {
      await ref.read(apiClientProvider).sendReminder(
            token: ref.read(authControllerProvider).token!,
            memberIds: [member['id'] as String],
            title: 'Contribution Reminder',
            message: 'Please check your latest contribution status and make payment if due.',
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

  Future<void> _editProfile(Map<String, dynamic> member) async {
    final nameController = TextEditingController(text: member['fullName'] as String? ?? '');
    final phoneController = TextEditingController(text: member['phone'] as String? ?? '');
    final emailController = TextEditingController(text: member['email'] as String? ?? '');
    final amountController = TextEditingController(text: '${member['monthlyContributionAmount'] ?? 0}');
    String selectedRole = member['role'] as String? ?? 'Player';
    String selectedStatus = member['status'] as String? ?? 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'Captain', child: Text('Captain')),
                    DropdownMenuItem(value: 'Setter', child: Text('Setter')),
                    DropdownMenuItem(value: 'Middle Blocker', child: Text('Middle Blocker')),
                    DropdownMenuItem(value: 'Libero', child: Text('Libero')),
                    DropdownMenuItem(value: 'Coach', child: Text('Coach')),
                    DropdownMenuItem(value: 'Player', child: Text('Player')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => selectedRole = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monthly Contribution'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => selectedStatus = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved != true) {
      return;
    }

    try {
      await ref.read(apiClientProvider).updateMember(
            ref.read(authControllerProvider).token!,
            widget.memberId,
            {
              'fullName': nameController.text.trim(),
              'phone': phoneController.text.trim(),
              'email': emailController.text.trim(),
              'role': selectedRole,
              'monthlyContributionAmount': int.tryParse(amountController.text.trim()) ?? 0,
              'status': selectedStatus,
            },
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      await _refresh();
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
          'Member Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlack),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.more_vert, color: AppColors.primaryBlack),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: FutureBuilder<_MemberProfileData>(
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

          final data = snapshot.data!;
          final member = data.member;
          final latestContribution = data.currentContribution;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
                _buildProfileHeader(member),
                const SizedBox(height: 16),
                _buildActionRow(member),
                const SizedBox(height: 16),
                _buildStatusCard(latestContribution),
                const SizedBox(height: 20),
                _buildSectionTitle('Member Information'),
                const SizedBox(height: 12),
                _buildInfoGrid(member),
                const SizedBox(height: 20),
                _buildSectionTitle('Payment History'),
                const SizedBox(height: 12),
                _buildPaymentHistory(data.contributions),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<_MemberProfileData>(
        future: _future,
        builder: (context, snapshot) {
          final member = snapshot.data?.member;
          if (member == null) {
            return const SizedBox.shrink();
          }

          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _recordPayment(member),
                      icon: const Icon(Icons.add_card, size: 18),
                      label: const Text('Record Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlack,
                        foregroundColor: AppColors.primaryYellow,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _sendReminder(member),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryYellow,
                        foregroundColor: AppColors.primaryBlack,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> member) {
    final fullName = member['fullName'] as String? ?? 'Unknown Member';
    final role = member['role'] as String? ?? 'Member';
    final joinDate = _formatJoinDate(member['joinDate'] as String?);
    final avatarUrl = member['avatarUrl'] as String?;
    final status = member['status'] as String? ?? 'inactive';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        _initials(fullName),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF64748B)),
                      )
                    : null,
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: status == 'active' ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            fullName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryBlack),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryBlack,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.primaryYellow),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            joinDate,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(Map<String, dynamic> member) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _editProfile(member),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: AppColors.primaryBlack,
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _sendReminder(member),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryBlack,
              minimumSize: const Size(0, 46),
              side: const BorderSide(color: AppColors.primaryBlack, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Message', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(Map<String, dynamic>? latestContribution) {
    final period = latestContribution?['period'] as String? ?? 'No current period';
    final status = latestContribution?['status'] as String? ?? 'unpaid';
    final isPaid = status == 'paid';
    final isPartial = status == 'partial';
    final statusColor = isPaid
        ? Colors.green
        : isPartial
            ? Colors.orange
            : Colors.red;
    final statusLabel = status.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlack),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current cycle: $period',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primaryYellow,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryBlack),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(Map<String, dynamic> member) {
    final items = [
      _InfoItem(Icons.call, 'Phone Number', member['phone'] as String? ?? '-'),
      _InfoItem(Icons.mail_outline, 'Email Address', member['email'] as String? ?? '-'),
      _InfoItem(Icons.payments_outlined, 'Monthly Contribution', 'RWF ${_number(member['monthlyContributionAmount'])}'),
      _InfoItem(Icons.badge_outlined, 'Membership ID', member['memberNumber'] as String? ?? '-'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: MediaQuery.of(context).size.width >= 720 ? (MediaQuery.of(context).size.width - 56) / 2 : double.infinity,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label.toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.value,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlack),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPaymentHistory(List<dynamic> contributions) {
    if (contributions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text('No payment history yet.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: contributions.map((entry) => _buildPaymentRow(entry as Map<String, dynamic>)).toList(),
      ),
    );
  }

  Widget _buildPaymentRow(Map<String, dynamic> contribution) {
    final status = contribution['status'] as String? ?? 'unpaid';
    final paidColor = status == 'paid'
        ? Colors.green
        : status == 'partial'
            ? Colors.orange
            : Colors.red;
    final payments = contribution['payments'] as List<dynamic>? ?? const [];
    final lastPayment = payments.isNotEmpty ? payments.first as Map<String, dynamic> : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: contribution == (contribution) ? Colors.transparent : AppColors.divider,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              contribution['period'] as String? ?? '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: status == 'unpaid' ? Colors.red.shade600 : AppColors.primaryBlack,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _money(contribution['totalPaid']),
              style: const TextStyle(fontSize: 14, color: AppColors.primaryBlack),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatShortDate(lastPayment?['paymentDate'] as String?),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: paidColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: paidColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatJoinDate(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) {
      return 'Member since -';
    }
    return 'Member since ${DateFormat('MMM yyyy').format(date)}';
  }

  String _formatShortDate(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) {
      return '-';
    }
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  String _money(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value['formatted'] as String? ?? 'RWF 0';
    }
    return 'RWF 0';
  }

  String _number(dynamic value) => NumberFormat('#,##0').format((value as num?) ?? 0);

  String _initials(String value) {
    final parts = value.split(' ').where((part) => part.isNotEmpty).take(2);
    final text = parts.map((part) => part[0].toUpperCase()).join();
    return text.isEmpty ? 'MV' : text;
  }
}

class _MemberProfileData {
  const _MemberProfileData({
    required this.member,
    required this.contributions,
  });

  final Map<String, dynamic> member;
  final List<dynamic> contributions;

  Map<String, dynamic>? get currentContribution {
    if (contributions.isEmpty) {
      return null;
    }
    return contributions.first as Map<String, dynamic>;
  }
}

class _InfoItem {
  const _InfoItem(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}
