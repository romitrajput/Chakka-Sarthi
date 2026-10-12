import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_strings.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/auth_repository.dart';

class SetMpinScreen extends ConsumerStatefulWidget {
  const SetMpinScreen({super.key});

  @override
  ConsumerState<SetMpinScreen> createState() => _SetMpinScreenState();
}

class _SetMpinScreenState extends ConsumerState<SetMpinScreen>
    with SingleTickerProviderStateMixin {
  String _mpin = '';
  String _confirmMpin = '';
  bool _isConfirmStep = false;
  bool _isLoading = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _shakeController.reverse();
      });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyTap(String key) {
    if (_isLoading) return;
    setState(() {
      if (key == 'back') {
        if (_isConfirmStep) {
          if (_confirmMpin.isNotEmpty) {
            _confirmMpin = _confirmMpin.substring(0, _confirmMpin.length - 1);
          }
        } else {
          if (_mpin.isNotEmpty) {
            _mpin = _mpin.substring(0, _mpin.length - 1);
          }
        }
      } else {
        if (_isConfirmStep) {
          if (_confirmMpin.length < 4) _confirmMpin += key;
          if (_confirmMpin.length == 4) _verifyMpin();
        } else {
          if (_mpin.length < 4) _mpin += key;
          if (_mpin.length == 4) setState(() => _isConfirmStep = true);
        }
      }
    });
  }

  void _verifyMpin() async {
    if (_mpin != _confirmMpin) {
      _shakeController.forward();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.mpinMismatch),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      Future.delayed(const Duration(milliseconds: 500), _reset);
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Direct repo call to update DB
      await AuthRepository().setMpin(user.userId, _mpin);

      // Refresh the provider so the app knows login is now fully complete
      ref.invalidate(authStateProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MPIN set successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        _reset();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _reset() {
    if (mounted) {
      setState(() {
        _mpin = '';
        _confirmMpin = '';
        _isConfirmStep = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentInput = _isConfirmStep ? _confirmMpin : _mpin;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
          onPressed: () {
            if (_isConfirmStep) {
              setState(() {
                _isConfirmStep = false;
                _confirmMpin = '';
              });
            } else {
              ref.read(authStateProvider.notifier).logout();
              context.go('/login');
            }
          },
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            _isConfirmStep ? AppStrings.confirmMpin : 'Set Your 4-Digit MPIN',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            AppStrings.setMpinSubtitle,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < currentInput.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? AppColors.primaryDark : Colors.transparent,
                        border: Border.all(
                          color: isFilled ? AppColors.primaryDark : AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: CircularProgressIndicator(),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              children: [
                ...['1', '2', '3', '4', '5', '6', '7', '8', '9']
                    .map((key) => _buildKey(key)),
                const SizedBox.shrink(),
                _buildKey('0'),
                _buildKey('back', isIcon: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String key, {bool isIcon = false}) {
    return InkWell(
      onTap: () => _onKeyTap(key),
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
        ),
        alignment: Alignment.center,
        child: isIcon
            ? const Icon(Icons.backspace_outlined,
                size: 24, color: AppColors.primaryDark)
            : Text(
                key,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
      ),
    );
  }
}
