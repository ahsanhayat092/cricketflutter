import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class DeliveryWheel extends StatelessWidget {
  final List<String> recentBalls;
  final String title;

  const DeliveryWheel({
    super.key,
    required this.recentBalls,
    this.title = 'RECENT DELIVERIES',
  });

  @override
  Widget build(BuildContext context) {
    if (recentBalls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                children: [
                  _buildLegendItem('6', AppColors.sixRuns),
                  const SizedBox(width: 8),
                  _buildLegendItem('4', AppColors.fourRuns),
                  const SizedBox(width: 8),
                  _buildLegendItem('W', AppColors.wicket),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentBalls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final ball = recentBalls[index];
                final color = AppColors.getDeliveryColor(ball);
                final isWicket = ball.contains('W');
                final isSix = ball == '6';
                final isFour = ball == '4';

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color,
                      width: isSix || isFour || isWicket ? 2.0 : 1.2,
                    ),
                    boxShadow: (isSix || isFour || isWicket)
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.35),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      ball,
                      style: GoogleFonts.outfit(
                        fontSize: ball.length > 2 ? 11 : 13,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
