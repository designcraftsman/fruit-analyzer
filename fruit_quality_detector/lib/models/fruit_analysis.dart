/// Represents the fruit analysis data from ML models
class FruitAnalysis {
  final String fruitType;
  final String ripeness;
  final String disease;
  final String? fruitDescription;
  final String? ripenessExplanation;
  final String? diseaseExplanation;

  FruitAnalysis({
    required this.fruitType,
    required this.ripeness,
    required this.disease,
    this.fruitDescription,
    this.ripenessExplanation,
    this.diseaseExplanation,
  });

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'fruit_type': fruitType,
      'ripeness': ripeness,
      'disease': disease,
      'fruit_description': fruitDescription,
      'ripeness_explanation': ripenessExplanation,
      'disease_explanation': diseaseExplanation,
    };
  }

  /// Get a formatted summary for context
  String toContextString() {
    final buffer = StringBuffer();
    buffer.writeln('Fruit Analysis Results:');
    buffer.writeln('- Fruit Type: $fruitType');
    buffer.writeln('- Ripeness: $ripeness');
    buffer.writeln('- Disease Status: $disease');

    if (fruitDescription != null) {
      buffer.writeln('- Description: $fruitDescription');
    }
    if (ripenessExplanation != null) {
      buffer.writeln('- Ripeness Details: $ripenessExplanation');
    }
    if (diseaseExplanation != null) {
      buffer.writeln('- Disease Details: $diseaseExplanation');
    }

    return buffer.toString();
  }

  /// Get nutritional summary (this could be expanded with a database)
  String getNutritionalSummary() {
    final fruitLower = fruitType.toLowerCase();

    // Basic nutritional data - in production, use a proper database
    final nutritionData = {
      'apple': {
        'calories': '95 per medium apple',
        'fiber': '4.4g',
        'vitamin_c': '14% DV',
        'sugar': '19g',
        'benefits': 'Rich in fiber and antioxidants, supports heart health',
      },
      'banana': {
        'calories': '105 per medium banana',
        'potassium': '422mg (12% DV)',
        'vitamin_b6': '20% DV',
        'sugar': '14g',
        'benefits': 'Excellent source of potassium, aids digestion',
      },
      'orange': {
        'calories': '62 per medium orange',
        'vitamin_c': '92% DV',
        'folate': '10% DV',
        'sugar': '12g',
        'benefits': 'High in vitamin C, boosts immunity',
      },
      'mango': {
        'calories': '99 per cup',
        'vitamin_a': '25% DV',
        'vitamin_c': '76% DV',
        'sugar': '23g',
        'benefits': 'Rich in vitamins A and C, supports eye health',
      },
      'strawberry': {
        'calories': '49 per cup',
        'vitamin_c': '149% DV',
        'manganese': '29% DV',
        'sugar': '7g',
        'benefits': 'Loaded with antioxidants, heart-healthy',
      },
    };

    for (var key in nutritionData.keys) {
      if (fruitLower.contains(key)) {
        final data = nutritionData[key]!;
        return 'Nutritional Information:\n'
            'Calories: ${data['calories']}\n'
            'Key Nutrients: ${data.entries.skip(1).take(2).map((e) => '${e.key}: ${e.value}').join(', ')}\n'
            'Benefits: ${data['benefits']}';
      }
    }

    return 'General nutritional benefits: Contains essential vitamins, minerals, and fiber.';
  }
}
