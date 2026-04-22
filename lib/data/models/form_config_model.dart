class FormFieldConfig {
  final String key;
  final String label;
  final bool required;
  final bool enabled;

  FormFieldConfig({
    required this.key,
    required this.label,
    required this.required,
    required this.enabled,
  });

  factory FormFieldConfig.fromJson(Map<String, dynamic> json) {
    return FormFieldConfig(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      required: json['required'] ?? false,
      enabled: json['enabled'] ?? true,
    );
  }
}
