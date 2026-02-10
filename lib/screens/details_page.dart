import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_background.dart';

class DetailsPage extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;

  const DetailsPage({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Transaction Details"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Reuse Liquid Background to maintain flow
          const LiquidBackground(),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                   Center(
                     child: Hero(
                       tag: title,
                       child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: Icon(icon, color: Colors.white, size: 48),
                        ),
                     ),
                   ),
                   const SizedBox(height: 24),
                   Text(
                     title,
                     style: const TextStyle(
                       color: Colors.white,
                       fontSize: 24,
                       fontWeight: FontWeight.bold,
                     ),
                   ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                   const SizedBox(height: 8),
                   Text(
                     amount,
                     style: TextStyle(
                       color: GlassTheme.accentColor,
                       fontSize: 32,
                       fontWeight: FontWeight.bold,
                     ),
                   ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                   
                   const SizedBox(height: 48),
                   
                   GlassCard(
                     width: double.infinity,
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _buildDetailRow("Status", "Completed", delay: 400),
                         const Divider(color: Colors.white24, height: 32),
                         _buildDetailRow("Date", "Oct 24, 2026", delay: 500),
                         const Divider(color: Colors.white24, height: 32),
                         _buildDetailRow("Transaction ID", "#890123912", delay: 600),
                       ],
                     ),
                   ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {int delay = 0}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
         Text(
           label,
           style: TextStyle(color: Colors.white60, fontSize: 16),
         ),
         Text(
           value,
           style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
         ),
      ],
    );
  }
}
