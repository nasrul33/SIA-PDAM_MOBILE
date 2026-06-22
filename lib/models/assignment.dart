/// Satu tugas baca-meter (GET /assignments). Angka meter selalu string (§0).
class Assignment {
  Assignment({
    required this.connectionId,
    required this.meterNo,
    required this.customerName,
    required this.address,
    required this.lastReading,
    required this.alreadyRead,
  });

  final int connectionId;
  final String meterNo;
  final String customerName;
  final String address;

  /// String desimal, mis. "1234.00".
  final String lastReading;

  /// true → sudah dibaca; blokir input ganda di UI.
  final bool alreadyRead;

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        connectionId: json['connection_id'] as int,
        meterNo: json['meter_no'] as String? ?? '',
        customerName: json['customer_name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        lastReading: (json['last_reading'] ?? '0').toString(),
        alreadyRead: json['already_read'] as bool? ?? false,
      );

  Map<String, dynamic> toDb(int periodId) => {
        'connection_id': connectionId,
        'period_id': periodId,
        'meter_no': meterNo,
        'customer_name': customerName,
        'address': address,
        'last_reading': lastReading,
        'already_read': alreadyRead ? 1 : 0,
      };

  factory Assignment.fromDb(Map<String, dynamic> row) => Assignment(
        connectionId: row['connection_id'] as int,
        meterNo: row['meter_no'] as String? ?? '',
        customerName: row['customer_name'] as String? ?? '',
        address: row['address'] as String? ?? '',
        lastReading: (row['last_reading'] ?? '0').toString(),
        alreadyRead: (row['already_read'] as int? ?? 0) == 1,
      );
}
