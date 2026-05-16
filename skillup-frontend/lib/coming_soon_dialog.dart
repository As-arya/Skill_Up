import 'package:flutter/material.dart';

class ComingSoonDialog extends StatelessWidget {
  const ComingSoonDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF151C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF13B5EA), Color(0xFF2C6CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF13B5EA).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.lock_reset, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 20),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF13B5EA).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF13B5EA).withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(
                  color: Color(0xFF13B5EA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Password Reset',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "We're working on a secure password reset flow. This feature will be available in a future update.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),

            // Info rows
            _InfoRow(icon: Icons.language, label: 'Language', color: const Color(0xFF13B5EA)),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.help_outline, label: 'Help & Support', color: const Color(0xFFB066FF)),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', color: const Color(0xFF00C896)),
            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13B5EA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('Coming Soon', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 11)),
      ]),
    );
  }
}
