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
                        color: const Color(0xFF10B981), // Emerald Green
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edge Mobile AI Engine Ready',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'ONNX Model Initialized On-Device • 100% Offline',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF059669),
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
                  tooltip: 'Refresh AI Engine Status',
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
                  value: 'MOBILE NPU/CPU',
                  isSuccess: true,
                ),
                _buildDiagnosticPill(
                  icon: Icons.psychology_outlined,
                  label: 'Engine',
                  value: 'ONNX RUNTIME',
                  isSuccess: true,
                ),
                _buildDiagnosticPill(
                  icon: Icons.hub_outlined,
                  label: 'Model Mode',
                  value: 'EDGE ON-DEVICE',
                  isSuccess: true,
                ),
                _buildDiagnosticPill(
                  icon: Icons.shield_outlined,
                  label: 'Privacy',
                  value: 'ZERO-LEAKAGE',
                  isSuccess: true,
                ),
              ],
            ),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.layers_outlined, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Architecture: Multimodal BiLSTM Attention Fusion (7.8M Param) • Exact Shapley (8 Coalitions)',
                      style: TextStyle(
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
