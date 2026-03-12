import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/auth_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';

class RegisterMemberScreen extends ConsumerStatefulWidget {
  const RegisterMemberScreen({super.key});

  @override
  ConsumerState<RegisterMemberScreen> createState() => _RegisterMemberScreenState();
}

class _RegisterMemberScreenState extends ConsumerState<RegisterMemberScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 3;

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _contributionController = TextEditingController();
  final _joinDateController = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);

  String? _selectedRole;
  String _status = 'active';
  bool _isSubmitting = false;

  final List<_StepInfo> _steps = const [
    _StepInfo(icon: Icons.person, title: 'Personal Details', subtitle: 'Name, phone & email'),
    _StepInfo(icon: Icons.sports_volleyball, title: 'Membership Info', subtitle: 'Role, contribution & date'),
    _StepInfo(icon: Icons.verified_user, title: 'Status & Review', subtitle: 'Confirm and register'),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _contributionController.dispose();
    _joinDateController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    final token = ref.read(authControllerProvider).token;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to register a member.')),
      );
      return;
    }

    if (_fullNameController.text.trim().isEmpty || _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name and role are required.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(apiClientProvider).createMember(token, {
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'monthlyContributionAmount': int.tryParse(_contributionController.text.replaceAll(',', '').trim()) ?? 0,
        'joinDate': _joinDateController.text.trim(),
        'status': _status,
        'notes': '',
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member registered successfully.')),
      );
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
          onPressed: _prevStep,
        ),
        title: const Text(
          'Register Member',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlack),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.border, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isCompleted = index < _currentStep;
              final isActive = index == _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    _buildStepDot(index, isActive, isCompleted),
                    if (index < _totalSteps - 1)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 2,
                          color: isCompleted ? AppColors.primaryYellow : AppColors.border,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey(_currentStep),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlack,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(_steps[_currentStep].icon, color: AppColors.primaryYellow, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _steps[_currentStep].title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlack),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    _steps[_currentStep].subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              minHeight: 4,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot(int index, bool isActive, bool isCompleted) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 32 : 28,
      height: isActive ? 32 : 28,
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.primaryYellow
            : isActive
                ? AppColors.primaryBlack
                : AppColors.border,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [BoxShadow(color: AppColors.primaryBlack.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: AppColors.primaryBlack, size: 14)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: isActive ? AppColors.primaryYellow : AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppTextField(
            label: 'Full Name',
            hintText: 'John Doe',
            controller: _fullNameController,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Phone Number',
            hintText: '+256 700 000 000',
            keyboardType: TextInputType.phone,
            controller: _phoneController,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Email Address',
            hintText: 'example@mvcs.com',
            keyboardType: TextInputType.emailAddress,
            controller: _emailController,
          ),
          const SizedBox(height: 24),
          _buildInfoBanner(Icons.info_outline, 'Fill in the member\'s contact information to proceed.'),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Role / Position',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primaryYellow, width: 2),
              ),
            ),
            hint: const Text('Select Role'),
            items: const [
              DropdownMenuItem(value: 'Captain', child: Text('Captain')),
              DropdownMenuItem(value: 'Setter', child: Text('Setter')),
              DropdownMenuItem(value: 'Middle Blocker', child: Text('Middle Blocker')),
              DropdownMenuItem(value: 'Libero', child: Text('Libero')),
              DropdownMenuItem(value: 'Coach', child: Text('Coach')),
              DropdownMenuItem(value: 'Player', child: Text('Player')),
            ],
            onChanged: (value) => setState(() => _selectedRole = value),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Monthly Contribution (RWF)',
            hintText: 'Enter amount',
            keyboardType: TextInputType.number,
            controller: _contributionController,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Join Date',
            hintText: 'YYYY-MM-DD',
            controller: _joinDateController,
          ),
          const SizedBox(height: 24),
          _buildInfoBanner(Icons.sports_volleyball, 'Provide membership details and contribution amount.'),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Member Status',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatusOption('active', 'Active', Icons.check_circle_outline)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusOption('inactive', 'Inactive', Icons.cancel_outlined)),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Review Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlack),
          ),
          const SizedBox(height: 12),
          _buildReviewCard(),
        ],
      ),
    );
  }

  Widget _buildStatusOption(String value, String label, IconData icon) {
    final isSelected = _status == value;
    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryYellow.withValues(alpha: 0.12) : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryYellow : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildReviewRow(Icons.person, 'Full Name', _fullNameController.text.isEmpty ? '-' : _fullNameController.text),
          _buildReviewDivider(),
          _buildReviewRow(Icons.phone, 'Phone', _phoneController.text.isEmpty ? '-' : _phoneController.text),
          _buildReviewDivider(),
          _buildReviewRow(Icons.email, 'Email', _emailController.text.isEmpty ? '-' : _emailController.text),
          _buildReviewDivider(),
          _buildReviewRow(Icons.sports_volleyball, 'Role', _selectedRole ?? '-'),
          _buildReviewDivider(),
          _buildReviewRow(Icons.payments, 'Monthly (RWF)', _contributionController.text.isEmpty ? '-' : _contributionController.text),
          _buildReviewDivider(),
          _buildReviewRow(Icons.calendar_today, 'Join Date', _joinDateController.text.isEmpty ? '-' : _joinDateController.text),
          _buildReviewDivider(),
          _buildReviewRow(
            _status == 'active' ? Icons.check_circle : Icons.cancel,
            'Status',
            _status == 'active' ? 'Active' : 'Inactive',
            valueColor: _status == 'active' ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.primaryBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewDivider() {
    return const Divider(height: 1, indent: 46, color: AppColors.divider);
  }

  Widget _buildInfoBanner(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryYellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryYellow.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBlack),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.primaryBlack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final isLastStep = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _prevStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  foregroundColor: AppColors.primaryBlack,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : isLastStep ? _submit : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep ? AppColors.primaryBlack : AppColors.primaryYellow,
                foregroundColor: isLastStep ? AppColors.primaryYellow : AppColors.primaryBlack,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSubmitting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(isLastStep ? Icons.how_to_reg : Icons.arrow_forward, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isSubmitting ? 'Saving...' : isLastStep ? 'Register Member' : 'Continue',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepInfo {
  const _StepInfo({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;
}
