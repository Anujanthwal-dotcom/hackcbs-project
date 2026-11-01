/// Standalone replacement for Firebase Timestamp when storing/reading JSON with MongoDB.
class Timestamp {
  final int seconds;
  final int nanoseconds;

  const Timestamp(this.seconds, this.nanoseconds);

  factory Timestamp.now() {
    return Timestamp.fromDate(DateTime.now());
  }

  factory Timestamp.fromDate(DateTime date) {
    final millis = date.millisecondsSinceEpoch;
    final seconds = (millis / 1000).floor();
    final nanoseconds = (millis % 1000) * 1000000;
    return Timestamp(seconds, nanoseconds);
  }

  DateTime toDate() {
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + (nanoseconds / 1000000).round());
  }

  static dynamic serverTimestamp() => DateTime.now().toIso8601String();

  @override
  String toString() => toDate().toIso8601String();
}

class FieldValue {
  static dynamic serverTimestamp() => DateTime.now().toIso8601String();
}

