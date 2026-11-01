import 'timestamp_compat.dart';

/// Represents a farmer's AI/RAG consultation thread stored in `users/{uid}/conversations/{conversationId}`.
class RagConversation {
  final String id;
  final String userId;
  final String title;
  final String? detectionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RagConversation({
    required this.id,
    required this.userId,
    required this.title,
    this.detectionId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      if (detectionId != null) 'detectionId': detectionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory RagConversation.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return RagConversation(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? 'New Chat',
      detectionId: map['detectionId'] as String?,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }
}

/// Represents an individual message in `users/{uid}/conversations/{conversationId}/messages/{messageId}`.
class RagMessage {
  final String id;
  final String conversationId;
  final String sender; // 'user' or 'assistant'
  final String text;
  final List<String>? retrievedSources;
  final DateTime timestamp;

  const RagMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.text,
    this.retrievedSources,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'sender': sender,
      'text': text,
      if (retrievedSources != null) 'retrievedSources': retrievedSources,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory RagMessage.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return RagMessage(
      id: id,
      conversationId: map['conversationId'] as String? ?? '',
      sender: map['sender'] as String? ?? 'user',
      text: map['text'] as String? ?? '',
      retrievedSources: (map['retrievedSources'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      timestamp: parseTimestamp(map['timestamp']),
    );
  }
}
