import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/animal_model.dart';
import '../services/language_service.dart';
import '../utils/constants.dart';

class AnimalCard extends StatelessWidget {
  final AnimalModel animal;
  final VoidCallback? onTap;
  final VoidCallback? onStatusChanged;
  final bool showOwner;

  const AnimalCard({
    super.key,
    required this.animal,
    this.onTap,
    this.onStatusChanged,
    this.showOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final statusColor =
        AppConstants.animalStatusColors[animal.status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: animal.isStolen
            ? BorderSide(color: Colors.red.shade300, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Animal Photo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    AppConstants.animalTypeIcons[animal.type] ?? '',
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),

              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      animal.animalId,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (showOwner)
                      Text(
                        '${languageService.translate('owner')}: ${animal.ownerfullName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      languageService.translate(animal.status.toLowerCase()),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (onStatusChanged != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (value) {
                        onStatusChanged!();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'ACTIVE',
                          child:
                              Text(languageService.translate('mark_as_active')),
                        ),
                        PopupMenuItem(
                          value: 'SOLD',
                          child:
                              Text(languageService.translate('mark_as_sold')),
                        ),
                        PopupMenuItem(
                          value: 'SLAUGHTERED',
                          child: Text(
                              languageService.translate('mark_as_slaughtered')),
                        ),
                        PopupMenuItem(
                          value: 'DEAD',
                          child:
                              Text(languageService.translate('mark_as_dead')),
                        ),
                        PopupMenuItem(
                          value: 'STOLEN',
                          child: Text(
                              languageService.translate('report_as_stolen')),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
