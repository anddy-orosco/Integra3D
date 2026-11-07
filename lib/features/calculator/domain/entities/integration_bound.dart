class IntegrationBound {
  final String variable;
  final String lower;
  final String upper;

  const IntegrationBound({
    required this.variable,
    required this.lower,
    required this.upper,
  });

  IntegrationBound copyWith({
    String? variable,
    String? lower,
    String? upper,
  }) {
    return IntegrationBound(
      variable: variable ?? this.variable,
      lower: lower ?? this.lower,
      upper: upper ?? this.upper,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variable': variable,
      'lower': lower,
      'upper': upper,
    };
  }

  factory IntegrationBound.fromJson(Map<String, dynamic> json) {
    return IntegrationBound(
      variable: json['variable'] as String? ?? 'x',
      lower: json['lower'] as String? ?? '0',
      upper: json['upper'] as String? ?? '1',
    );
  }
}
