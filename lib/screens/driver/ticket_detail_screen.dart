import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/status_chip.dart';
import 'package:sanjay_roadlines_fleet/models/loading_status_model.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/loading_unloading_repository.dart';
import 'package:sanjay_roadlines_fleet/app.dart';

final ticketDetailProvider =
    FutureProvider.autoDispose.family<TicketModel, String>((ref, ticketId) async {
  return ref.watch(ticketRepositoryProvider).getTicketById(ticketId);
});

final loadingStatusProvider =
    FutureProvider.autoDispose.family<LoadingStatusModel?, String>((ref, ticketId) async {
  return LoadingUnloadingRepository().getLoadingStatus(ticketId);
});

final vehicleNumberDetailProvider =
    FutureProvider.family<String, String>((ref, vehicleId) async {
  return ref.watch(ticketRepositoryProvider).getVehicleNumber(vehicleId);
});

class TicketDetailScreen extends ConsumerWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketAsync = ref.watch(ticketDetailProvider(ticketId));
    final loadingAsync = ref.watch(loadingStatusProvider(ticketId));
    final user = ref.watch(authStateProvider).value;
    final currentLocale = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(ticketId,
            style: const TextStyle(fontSize: 14, letterSpacing: 0.5)),
      ),
      body: ticketAsync.when(
        data: (ticket) {
          // Trip moved to another driver: nothing more can be done on it here
          if (user != null && user.role != 'admin' && ticket.driverUserId != user.userId) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_horiz, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('This trip has been re-assigned to another driver.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('You no longer need to do anything on it.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(ticketStateProvider);
                        Navigator.of(context).maybePop();
                      },
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }
          final vehicleAsync =
              ref.watch(vehicleNumberDetailProvider(ticket.vehicleId));

          return loadingAsync.when(
            data: (loading) {
              final isLoadingDone = loading != null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        children: [
                          _infoRow(
                            Icons.directions_car_outlined,
                            currentLocale.languageCode == 'hi' ? 'वाहन' : 'Vehicle',
                            vehicleAsync.maybeWhen(
                                data: (v) => v, orElse: () => '...'),
                          ),
                          const Divider(height: 20),
                          _infoRow(Icons.person_outline, 
                            currentLocale.languageCode == 'hi' ? 'चालक' : 'Driver',
                            user?.fullName ?? ''),
                          const Divider(height: 20),
                          _infoRow(Icons.access_time_outlined,
                            currentLocale.languageCode == 'hi' ? 'सौंपा गया' : 'Assigned',
                            ticket.formattedAssignedAt),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(currentLocale.languageCode == 'hi' ? 'स्थिति' : 'Status',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              StatusChip(status: ticket.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Loading button
                    _actionButton(
                      label: currentLocale.languageCode == 'hi' ? 'लोडिंग स्थिति' : 'LOADING STATUS',
                      icon: isLoadingDone
                          ? Icons.lock_outline
                          : Icons.upload_outlined,
                      bg: isLoadingDone
                          ? AppColors.successGreen
                          : AppColors.primaryDark,
                      enabled: !isLoadingDone,
                      onTap: () async {
                        final result = await context.push<bool>(
                          '/driver/loading-form/$ticketId',
                        );

                        if (result == true) {
                          ref.invalidate(loadingStatusProvider(ticketId));
                          ref.invalidate(ticketDetailProvider(ticketId));
                          await ref.read(ticketStateProvider.notifier).refresh();
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Unloading button
                    _actionButton(
                      label: currentLocale.languageCode == 'hi' ? 'अनलोडिंग स्थिति' : 'UNLOADING STATUS',
                      icon: Icons.download_outlined,
                      bg: isLoadingDone
                          ? AppColors.errorRed
                          : const Color(0xFFFFCDD2),
                      textColor: isLoadingDone
                          ? Colors.white
                          : AppColors.errorRed,
                      enabled: true,
                      onTap: () {
                        if (!isLoadingDone) {
                          _showDialog(context, currentLocale);
                        } else {
                          context.push('/driver/unloading-form/$ticketId');
                        }
                      },
                    ),

                    // Loading details
                    if (isLoadingDone) ...[
                      const SizedBox(height: 28),
                      Text(currentLocale.languageCode == 'hi' ? 'लोडिंग विवरण' : 'Loading Details',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            _detailTile('LR Number', loading.lrNumber),
                            _divider(),
                            _detailTile(currentLocale.languageCode == 'hi' ? 'कहां से' : 'From', loading.journeyFrom),
                            _divider(),
                            _detailTile(currentLocale.languageCode == 'hi' ? 'कहां तक' : 'To', loading.journeyTo),
                            _divider(),
                            _detailTile(
                                currentLocale.languageCode == 'hi' ? 'संवाहक' : 'Consignee', loading.consigneeName),
                            _divider(),
                            _detailTile(currentLocale.languageCode == 'hi' ? 'उत्पाद' : 'Product', loading.product),
                            _divider(),
                            _detailTile(currentLocale.languageCode == 'hi' ? 'लोडिंग वजन' : 'Loading Weight',
                                '${loading.loadingWeightKgs.toStringAsFixed(2)} Kgs'),
                          ],
                        ),
                      ),
                    ],

                    // Show detention days if available
                    if (ticket.detentionDays != null) ...[
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryMid.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, color: AppColors.primaryDark),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(currentLocale.languageCode == 'hi' ? 'अवरोध दिवस' : 'Detention Days',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text('${ticket.detentionDays} days',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error loading details: $e')),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error loading trip: $e')),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryMid, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color bg,
    Color textColor = Colors.white,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: textColor,
          disabledBackgroundColor: bg,
          disabledForegroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: enabled ? onTap : null,
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 16, endIndent: 16);

  void _showDialog(BuildContext context, Locale locale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warningYellow),
            const SizedBox(width: 8),
            Text(locale.languageCode == 'hi' ? 'कार्य आवश्यक' : 'Action Required'),
          ],
        ),
        content: Text(
            locale.languageCode == 'hi' ? 'कृपया पहले लोडिंग स्थिति पूरी करें' : 'Please complete Loading Status first before starting unloading.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandYellow,
                foregroundColor: AppColors.onBrandYellow,),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
