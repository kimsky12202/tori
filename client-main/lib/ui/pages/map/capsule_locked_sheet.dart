import 'package:flutter/material.dart';

import 'tourist_spot_models.dart';

class CapsuleLockedSheet extends StatelessWidget {
  const CapsuleLockedSheet({
    super.key,
    required this.capsule,
    this.spotName,
  });

  final CapsuleMapMarker capsule;
  final String? spotName;

  @override
  Widget build(BuildContext context) {
    final locked = capsule.isLocked;
    final title = (spotName?.isNotEmpty ?? false)
        ? '${spotName!} 캡슐'
        : (capsule.emotion?.isNotEmpty ?? false)
            ? '${capsule.emotion} 캡슐'
            : '나의 캡슐';

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D5CC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: locked
                        ? const Color(0xFFA14040).withValues(alpha: 0.12)
                        : const Color(0xFF1FAA8C).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    locked ? Icons.lock_outline : Icons.lock_open_outlined,
                    color: locked
                        ? const Color(0xFFA14040)
                        : const Color(0xFF1FAA8C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2B2A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locked ? '아직 열 수 없는 캡슐이에요' : '지금 열어볼 수 있어요',
                        style: TextStyle(
                          fontSize: 12,
                          color: locked
                              ? const Color(0xFFA14040)
                              : const Color(0xFF1FAA8C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: '묻은 날짜',
              value: _formatDate(capsule.buriedAt ?? capsule.createdAt),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.hourglass_bottom_outlined,
              label: locked ? '잠금 해제까지' : '잠금 해제됨',
              value: _formatRemaining(capsule),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.event_available_outlined,
              label: '열람 가능 시점',
              value: _formatOpenAt(capsule),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E2B2A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '닫기',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _formatOpenAt(CapsuleMapMarker capsule) {
    final option = capsule.openOption ?? 'anytime';
    if (option == 'anytime') return '언제든지 열람 가능';
    final openAt = capsule.openAt;
    if (openAt == null) return '-';
    final local = openAt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  static String _formatRemaining(CapsuleMapMarker capsule) {
    if (capsule.canOpenNow) return '바로 열람 가능';
    final openAt = capsule.openAt;
    if (openAt == null) return '-';
    final remaining = openAt.difference(DateTime.now());
    if (remaining.isNegative) return '바로 열람 가능';
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    if (days > 0) return '$days일 ${hours}시간 남음';
    if (hours > 0) return '$hours시간 $minutes분 남음';
    return '$minutes분 남음';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF7A756D)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A756D),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF2E2B2A),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
