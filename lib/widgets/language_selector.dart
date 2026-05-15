import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

class LanguageSelector extends StatelessWidget {
  final Function(String)? onLanguageChanged;
  final bool showLabel;

  const LanguageSelector({
    super.key,
    this.onLanguageChanged,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        final currentLanguage = languageService.currentLocale.languageCode;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLabel)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    languageService.translate('language'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              _buildLanguageButton(
                context,
                'EN',
                currentLanguage == 'en',
                () async {
                  print('Changing language to English');
                  await languageService.setLanguage('en');
                  if (onLanguageChanged != null) onLanguageChanged!('en');
                },
              ),
              _buildLanguageButton(
                context,
                'SW',
                currentLanguage == 'sw',
                () async {
                  print('Changing language to Swahili');
                  await languageService.setLanguage('sw');
                  if (onLanguageChanged != null) onLanguageChanged!('sw');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageButton(
    BuildContext context,
    String text,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
