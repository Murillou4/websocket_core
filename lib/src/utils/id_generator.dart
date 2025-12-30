import 'dart:math';

/// Interface para geração de IDs
abstract class IdGenerator {
  const IdGenerator();

  /// Gera um novo ID único
  String generate();
}

/// Gerador de UUIDs v4
class UuidGenerator implements IdGenerator {
  const UuidGenerator();

  @override
  String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Ajusta versão (v4) e variante
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant

    return _bytesToUuid(bytes);
  }

  String _bytesToUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}

/// Gerador de IDs curtos (para debugging/desenvolvimento)
class ShortIdGenerator implements IdGenerator {
  final String _prefix;
  int _counter = 0;

  ShortIdGenerator([this._prefix = 'conn']);

  @override
  String generate() {
    _counter++;
    final random = Random().nextInt(9999);
    return '${_prefix}_${_counter}_$random';
  }
}

/// Gerador baseado em timestamp + random
class TimestampIdGenerator implements IdGenerator {
  const TimestampIdGenerator();

  @override
  String generate() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure().nextInt(0xFFFFFF);
    return '${now.toRadixString(36)}-${random.toRadixString(36)}';
  }
}
