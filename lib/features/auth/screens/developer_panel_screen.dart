import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/auth_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

class DeveloperPanelScreen extends ConsumerStatefulWidget {
  const DeveloperPanelScreen({super.key});

  @override
  ConsumerState<DeveloperPanelScreen> createState() =>
      _DeveloperPanelScreenState();
}

class _DeveloperPanelScreenState extends ConsumerState<DeveloperPanelScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createAsDisabled = false;
  bool _isCreating = false;
  late Future<_DeveloperPanelData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<_DeveloperPanelData> _load() async {
    final token = ref.read(authControllerProvider).token!;
    final api = ref.read(apiClientProvider);
    final results = await Future.wait<dynamic>([
      api.getPlatformOverview(token),
      api.getPlatformAccounts(token),
    ]);

    return _DeveloperPanelData(
      overview: results[0] as Map<String, dynamic>,
      accounts: results[1] as List<dynamic>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _createAccount() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full name, email, and password are required.'),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      await ref
          .read(apiClientProvider)
          .createPlatformAccount(ref.read(authControllerProvider).token!, {
            'fullName': fullName,
            'email': email,
            'password': password,
            'phone': phone,
            'status': _createAsDisabled ? 'disabled' : 'active',
          });

      _fullNameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _passwordController.clear();

      if (mounted) {
        setState(() => _createAsDisabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Independent admin account created.')),
        );
      }

      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> account) async {
    final nextStatus = account['status'] == 'active' ? 'disabled' : 'active';

    try {
      await ref.read(apiClientProvider).updatePlatformAccount(
        ref.read(authControllerProvider).token!,
        account['id'] as String,
        {'status': nextStatus},
      );
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlack),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text(
          'Developer Panel',
          style: TextStyle(
            color: AppColors.primaryBlack,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<_DeveloperPanelData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final errorText = _errorText(snapshot.error);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Developer data failed to load',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(errorText, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final overview = data.overview;
          final accounts = data.accounts.cast<Map<String, dynamic>>();
          final accountStats =
              overview['accounts'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
          final systemStats =
              overview['system'] as Map<String, dynamic>? ??
              const <String, dynamic>{};

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHero(accountStats, systemStats),
                const SizedBox(height: 16),
                _buildCreateCard(),
                const SizedBox(height: 16),
                const Text(
                  'Account Inventory',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlack,
                  ),
                ),
                const SizedBox(height: 8),
                ...accounts.map(_buildAccountCard),
                if (accounts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'No customer admin accounts exist yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(
    Map<String, dynamic> accountStats,
    Map<String, dynamic> systemStats,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111111), Color(0xFF353535)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Platform Control',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${accountStats['total'] ?? 0} customer accounts, ${systemStats['members'] ?? 0} members, ${systemStats['payments'] ?? 0} payments.',
            style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 14),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildPill('Active', '${accountStats['active'] ?? 0}'),
              _buildPill('Disabled', '${accountStats['disabled'] ?? 0}'),
              _buildPill(
                'New 30d',
                '${accountStats['createdLast30Days'] ?? 0}',
              ),
              _buildPill(
                'Logins 7d',
                '${accountStats['loggedInLast7Days'] ?? 0}',
              ),
              _buildPill(
                'Collected',
                'RWF ${systemStats['collectedAmount'] ?? 0}',
              ),
              _buildPill(
                'Notifications',
                '${systemStats['notifications'] ?? 0}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Provision Independent Admin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Full Name',
            controller: _fullNameController,
            hintText: 'Account owner name',
            prefixIcon: const Icon(Icons.person_outline),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Email',
            controller: _emailController,
            hintText: 'owner@company.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Phone',
            controller: _phoneController,
            hintText: 'Optional',
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Temporary Password',
            controller: _passwordController,
            hintText: 'At least 8 characters',
            obscureText: true,
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Create as disabled'),
            subtitle: const Text(
              'Keep the account blocked until you are ready to hand it over.',
            ),
            value: _createAsDisabled,
            onChanged: (value) => setState(() => _createAsDisabled = value),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            text: 'Create Admin Account',
            onPressed: _createAccount,
            isLoading: _isCreating,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final totals =
        account['totals'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final isActive = account['status'] == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isActive
                    ? AppColors.primaryYellow
                    : AppColors.backgroundLight,
                child: Text(
                  _initials(account['fullName'] as String? ?? 'A'),
                  style: const TextStyle(
                    color: AppColors.primaryBlack,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account['fullName'] as String? ?? 'Unnamed account',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account['email'] as String? ?? '',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if ((account['phone'] as String?)?.isNotEmpty == true)
                      Text(
                        account['phone'] as String,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _toggleStatus(account),
                style: FilledButton.styleFrom(
                  backgroundColor: isActive
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  foregroundColor: isActive
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
                child: Text(isActive ? 'Disable' : 'Enable'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                isActive ? 'ACTIVE' : 'DISABLED',
                isActive ? Colors.green.shade700 : Colors.red.shade700,
              ),
              _buildInfoChip(
                'Members ${totals['members'] ?? 0}',
                AppColors.textSecondary,
              ),
              _buildInfoChip(
                'Payments ${totals['payments'] ?? 0}',
                AppColors.textSecondary,
              ),
              _buildInfoChip(
                'Notifications ${totals['notifications'] ?? 0}',
                AppColors.textSecondary,
              ),
              _buildInfoChip(
                'Settings ${totals['settings'] ?? 0}',
                AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Created ${_formatDate(account['createdAt'])} • Last login ${_formatDate(account['lastLoginAt'])}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value is! String || value.isEmpty) {
      return 'never';
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      return 'unknown';
    }
    return DateFormat('dd MMM yyyy, HH:mm').format(date.toLocal());
  }

  String _initials(String value) {
    final parts = value.split(' ').where((part) => part.isNotEmpty).take(2);
    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'AD' : initials;
  }

  String _errorText(Object? error) {
    if (error is ApiException) {
      final status = error.statusCode == null ? '' : ' (${error.statusCode})';
      return '${error.message}$status';
    }
    return error?.toString() ?? 'Unknown error';
  }
}

class _DeveloperPanelData {
  const _DeveloperPanelData({required this.overview, required this.accounts});

  final Map<String, dynamic> overview;
  final List<dynamic> accounts;
}
