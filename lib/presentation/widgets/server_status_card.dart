import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/screening_provider.dart';

class ServerStatusCard extends StatelessWidget {
  const ServerStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreeningProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: provider.isServerHealthy
                            ? const Color(0xFF10B981) // Emerald Green
                            : const Color(0xFFEF4444), // Crimson
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (provider.isServerHealthy
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444))
                                .withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.isServerHealthy
                              ? 'Mesin Inferensi AI Siap'
                              : 'Koneksi Server Terputus',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          provider.isServerHealthy
                              ? 'Koneksi API Aman & Layanan Aktif'
                              : 'Tidak dapat terhubung ke server inferensi',
                          style: TextStyle(
                            fontSize: 11,
                            color: provider.isServerHealthy
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: provider.isCheckingHealth
                      ? null
                      : () => provider.checkServerHealth(),
                  icon: provider.isCheckingHealth
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 20),
                  tooltip: 'Cek Ulang Status Mesin AI',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Diagnostic Badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildDiagnosticPill(
                  icon: Icons.speed_rounded,
                  label: 'Hardware',
                  value: provider.serverDevice.toUpperCase(),
                  isSuccess: provider.serverDevice.toLowerCase().contains('cuda'),
                ),
                _buildDiagnosticPill(
                  icon: Icons.psychology_outlined,
                  label: 'Model Status',
                  value: provider.isModelLoaded ? 'READY' : 'MEMUAT',
                  isSuccess: provider.isModelLoaded,
                ),
                _buildDiagnosticPill(
                  icon: Icons.shield_outlined,
                  label: 'Privasi',
                  value: 'RAM-ONLY',
                  isSuccess: true,
                ),
              ],
            ),

            if (provider.modelInfo != null && provider.modelInfo!['architecture'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.layers_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Arsitektur: ${provider.modelInfo!['architecture']} (${provider.modelInfo!['model'] ?? 'Baseline'})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (provider.errorMessage != null && !provider.isServerHealthy) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Peringatan: ${provider.errorMessage!}. Pastikan server FastAPI aktif di port 8000.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB91C1C),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticPill({
    required IconData icon,
    required String label,
    required String value,
    required bool isSuccess,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSuccess ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
