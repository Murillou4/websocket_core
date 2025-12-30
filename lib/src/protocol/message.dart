import 'dart:convert';

/// Estrutura base de mensagem WebSocket.
///
/// Toda comunicação segue este formato explícito:
/// - [version]: versão do protocolo (ex: "1.0")
/// - [event]: tipo do evento (ex: "chat.message", "user.join")
/// - [payload]: dados da mensagem
/// - [correlationId]: ID para correlacionar request/response (opcional)
class WsMessage {
  /// Versão do protocolo
  final String version;

  /// Tipo/nome do evento
  final String event;

  /// Payload da mensagem
  final Map<String, dynamic> payload;

  /// ID de correlação para request/response
  final String? correlationId;

  /// Timestamp da mensagem
  final DateTime timestamp;

  const WsMessage({
    required this.version,
    required this.event,
    this.payload = const {},
    this.correlationId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const _Now();

  /// Cria mensagem a partir de JSON string
  factory WsMessage.fromJson(String jsonString) {
    final data = json.decode(jsonString) as Map<String, dynamic>;
    return WsMessage.fromMap(data);
  }

  /// Cria mensagem a partir de Map
  factory WsMessage.fromMap(Map<String, dynamic> data) {
    return WsMessage(
      version: data['v'] as String? ?? '1.0',
      event: data['e'] as String,
      payload: data['p'] as Map<String, dynamic>? ?? {},
      correlationId: data['c'] as String?,
      timestamp: data['t'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['t'] as int)
          : null,
    );
  }

  /// Converte para Map
  Map<String, dynamic> toMap() {
    return {
      'v': version,
      'e': event,
      'p': payload,
      if (correlationId != null) 'c': correlationId,
      't': timestamp.millisecondsSinceEpoch,
    };
  }

  /// Converte para JSON string
  String toJson() => json.encode(toMap());

  /// Cria cópia com modificações
  WsMessage copyWith({
    String? version,
    String? event,
    Map<String, dynamic>? payload,
    String? correlationId,
    DateTime? timestamp,
  }) {
    return WsMessage(
      version: version ?? this.version,
      event: event ?? this.event,
      payload: payload ?? this.payload,
      correlationId: correlationId ?? this.correlationId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() => 'WsMessage($event, v$version)';
}

/// Helper class para default timestamp
class _Now implements DateTime {
  const _Now();

  DateTime get _now => DateTime.now();

  @override
  DateTime add(Duration duration) => _now.add(duration);

  @override
  int compareTo(DateTime other) => _now.compareTo(other);

  @override
  int get day => _now.day;

  @override
  Duration difference(DateTime other) => _now.difference(other);

  @override
  int get hashCode => _now.hashCode;

  @override
  int get hour => _now.hour;

  @override
  bool isAfter(DateTime other) => _now.isAfter(other);

  @override
  bool isAtSameMomentAs(DateTime other) => _now.isAtSameMomentAs(other);

  @override
  bool isBefore(DateTime other) => _now.isBefore(other);

  @override
  bool get isUtc => _now.isUtc;

  @override
  int get microsecond => _now.microsecond;

  @override
  int get microsecondsSinceEpoch => _now.microsecondsSinceEpoch;

  @override
  int get millisecond => _now.millisecond;

  @override
  int get millisecondsSinceEpoch => _now.millisecondsSinceEpoch;

  @override
  int get minute => _now.minute;

  @override
  int get month => _now.month;

  @override
  int get second => _now.second;

  @override
  DateTime subtract(Duration duration) => _now.subtract(duration);

  @override
  String get timeZoneName => _now.timeZoneName;

  @override
  Duration get timeZoneOffset => _now.timeZoneOffset;

  @override
  String toIso8601String() => _now.toIso8601String();

  @override
  DateTime toLocal() => _now.toLocal();

  @override
  DateTime toUtc() => _now.toUtc();

  @override
  int get weekday => _now.weekday;

  @override
  int get year => _now.year;

  @override
  bool operator ==(Object other) => _now == other;
}
