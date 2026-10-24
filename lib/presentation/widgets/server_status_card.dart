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
                            ? const Color(0xFF10B981) // Green
                            : const Color(0xFFEF4444), // Red
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.isServerHealthy
                          ? 'Server FastAPI Terhubung'
                          : 'Server Offline',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
                      : const Icon(Icons.refresh, size: 20),
                  tooltip: 'Cek Ulang Server',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildInfoPill(
                  icon: Icons.memory,
                  label: 'Device',
                  value: provider.serverDevice.toUpperCase(),
                  isHighlight: provider.serverDevice.toLowerCase().contains('cuda'),
                ),
                const SizedBox(width: 8),
                _buildInfoPill(
                  icon: Icons.psychology_outlined,
                  label: 'Model Loaded',
                  value: provider.isModelLoaded ? 'READY' : 'NOT LOADED',
                  isHighlight: provider.isModelLoaded,
                ),
              ],
            ),
            if (provider.modelInfo != null && provider.modelInfo!['architecture'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Arsitektur: ${provider.modelInfo!['architecture']} (${provider.modelInfo!['model'] ?? 'Baseline'})',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
            if (provider.errorMessage != null && !provider.isServerHealthy) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required String value,
    required bool isHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
