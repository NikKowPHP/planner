import 'package:flutter/material.dart';
import 'package:glass_kit/glass_kit.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      height: 56,
      width: double.infinity,
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.2),
          Colors.white.withOpacity(0.1),
        ],
      ),
      blur: 20,
      borderWidth: 1,
      elevation: 3,
      isFrostedGlass: true,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(
                  prefixIcon,
                  color: Colors.white.withOpacity(0.7),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
