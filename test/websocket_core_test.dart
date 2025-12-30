import 'package:websocket_core/websocket_core.dart';
import 'package:test/test.dart';

void main() {
  group('WsMessage', () {
    test('should create message with required fields', () {
      final message = WsMessage(
        version: '1.0',
        event: 'test.event',
        payload: {'key': 'value'},
      );

      expect(message.version, equals('1.0'));
      expect(message.event, equals('test.event'));
      expect(message.payload['key'], equals('value'));
    });

    test('should serialize to JSON', () {
      final message = WsMessage(
        version: '1.0',
        event: 'test.event',
        payload: {'foo': 'bar'},
      );

      final json = message.toJson();
      expect(json, contains('"e":"test.event"'));
      expect(json, contains('"v":"1.0"'));
    });

    test('should deserialize from JSON', () {
      final json = '{"v":"1.0","e":"test.event","p":{"key":"value"}}';
      final message = WsMessage.fromJson(json);

      expect(message.version, equals('1.0'));
      expect(message.event, equals('test.event'));
      expect(message.payload['key'], equals('value'));
    });
  });

  group('WsProtocol', () {
    test('should validate correct message', () {
      final protocol = WsProtocol();
      final result = protocol.validate('{"e":"test"}');

      expect(result.isValid, isTrue);
      expect(result.message?.event, equals('test'));
    });

    test('should reject invalid JSON', () {
      final protocol = WsProtocol();
      final result = protocol.validate('not json');

      expect(result.isValid, isFalse);
      expect(result.error, contains('Invalid JSON'));
    });

    test('should reject missing event', () {
      final protocol = WsProtocol();
      final result = protocol.validate('{"p":{}}');

      expect(result.isValid, isFalse);
      expect(result.error, contains('event'));
    });
  });

  group('WsSession', () {
    test('should track state correctly', () {
      final session = WsSession(sessionId: 'test-123');

      expect(session.isActive, isTrue);
      expect(session.isSuspended, isFalse);

      session.suspend();
      expect(session.isActive, isFalse);
      expect(session.isSuspended, isTrue);
    });

    test('should track rooms', () {
      final session = WsSession(sessionId: 'test-123');

      session.joinRoom('room-1');
      session.joinRoom('room-2');

      expect(session.rooms, contains('room-1'));
      expect(session.rooms, contains('room-2'));

      session.leaveRoom('room-1');
      expect(session.rooms, isNot(contains('room-1')));
    });
  });

  group('WsRoom', () {
    test('should track sessions', () {
      final room = WsRoom(roomId: 'test-room');

      expect(room.isEmpty, isTrue);

      room.addSession('session-1');
      room.addSession('session-2');

      expect(room.memberCount, equals(2));
      expect(room.hasSession('session-1'), isTrue);

      room.removeSession('session-1');
      expect(room.memberCount, equals(1));
      expect(room.hasSession('session-1'), isFalse);
    });

    test('should respect max members', () {
      final room = WsRoom(roomId: 'test-room', maxMembers: 2);

      expect(room.addSession('s1'), isTrue);
      expect(room.addSession('s2'), isTrue);
      expect(room.addSession('s3'), isFalse);
      expect(room.isFull, isTrue);
    });
  });
}
