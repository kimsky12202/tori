import 'package:flutter/material.dart';

import 'tourist_spot_models.dart';

class SpotDetailSheet extends StatelessWidget {
  const SpotDetailSheet({
    super.key,
    required this.spot,
    required this.onCheckIn,
    this.isWithinRadius = false,
    this.isCheckingIn = false,
  });

  final TouristSpot spot;
  final VoidCallback onCheckIn;
  final bool isWithinRadius;
  final bool isCheckingIn;

  @override
  Widget build(BuildContext context) {
    final visited = spot.visited;
    final color = spot.markerColor;

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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: visited
                        ? color.withValues(alpha: 0.18)
                        : const Color(0xFFE7E3D8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    visited ? spot.markerIcon : Icons.help_outline,
                    color: visited ? color : const Color(0xFF7A756D),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visited ? spot.name : '미발견 장소',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2B2A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visited
                            ? (spot.description ?? '발견한 관광지')
                            : '근처에 도착해 발견해보세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: visited
                              ? const Color(0xFF7A756D)
                              : const Color(0xFFA14040),
                        ),
                      ),
                    ],
                  ),
                ),
                if (visited)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          '완료',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (visited)
              _InfoRow(
                icon: Icons.task_alt_outlined,
                label: '인증 방법',
                value: _formatSource(spot.visit?.source),
              )
            else
              _InfoRow(
                icon: Icons.radar,
                label: '인증 반경',
                value: '${spot.radiusMeters}m 이내',
              ),
            const SizedBox(height: 8),
            if (visited)
              _InfoRow(
                icon: Icons.event_outlined,
                label: '인증 날짜',
                value: _formatDate(spot.visit?.visitedAt),
              )
            else
              _InfoRow(
                icon: Icons.lightbulb_outline,
                label: '인증 방법',
                value: 'AR 또는 캡슐 등록',
              ),
            const SizedBox(height: 20),
            if (!visited)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (isCheckingIn || !isWithinRadius) ? null : onCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FAA8C),
                    disabledBackgroundColor: const Color(0xFFC9C5BB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: isCheckingIn
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.gps_fixed, color: Colors.white),
                  label: Text(
                    isWithinRadius ? '여기서 인증하기' : '범위 밖이에요',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFD9D5CC)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '닫기',
                    style: TextStyle(color: Color(0xFF2E2B2A), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatSource(VisitSource? source) {
    switch (source) {
      case VisitSource.capsule:
        return '캡슐 등록';
      case VisitSource.ar:
        return 'AR 인증';
      case VisitSource.manual:
        return '수동 인증';
      default:
        return '인증 완료';
    }
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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
          Text(label, style: const TextStyle(color: Color(0xFF7A756D), fontSize: 13)),
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
