class Period {
  Period({required this.id, required this.code});

  final int id;

  /// Kode periode, mis. "2026-06".
  final String code;

  factory Period.fromJson(Map<String, dynamic> json) => Period(
        id: json['id'] as int,
        code: json['code'] as String? ?? '',
      );
}
