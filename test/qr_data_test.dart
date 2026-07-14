import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter_test/flutter_test.dart';

import 'encoder_test.dart' show decodeWithZxing;

void main() {
  group('QrData payload builders', () {
    test('wifi with escaping', () {
      final payload = QrData.wifi(
        ssid: 'My;Cafe:2G',
        password: r'pass"word\1,2',
      );
      expect(payload, r'WIFI:T:WPA;S:My\;Cafe\:2G;P:pass\"word\\1\,2;;');
    });

    test('wifi open network omits password', () {
      expect(QrData.wifi(ssid: 'Open', security: QrWifiSecurity.none),
          'WIFI:T:nopass;S:Open;;');
    });

    test('wifi hidden network', () {
      expect(QrData.wifi(ssid: 'X', password: 'y', hidden: true),
          contains('H:true;'));
    });

    test('email builds a mailto URI', () {
      final payload = QrData.email(
          to: 'hi@example.com', subject: 'Hello there', body: 'A & B');
      expect(payload, startsWith('mailto:hi@example.com?'));
      final uri = Uri.parse(payload);
      expect(uri.queryParameters['subject'], 'Hello there');
      expect(uri.queryParameters['body'], 'A & B');
    });

    test('sms with and without message', () {
      expect(QrData.sms(phone: '+1 (555) 123-4567', message: 'Hi!'),
          'SMSTO:+15551234567:Hi!');
      expect(QrData.sms(phone: '555 123'), 'SMSTO:555123');
    });

    test('phone keeps leading plus only', () {
      expect(QrData.phone('+49 (0) 171/123'), 'tel:+490171123');
    });

    test('whatsapp strips non-digits and encodes text', () {
      expect(QrData.whatsapp(phone: '+1 555-000-1111', text: 'Hello & bye'),
          'https://wa.me/15550001111?text=Hello%20%26%20bye');
    });

    test('geo with search query', () {
      expect(QrData.geo(latitude: 52.52, longitude: 13.405, query: 'Berlin'),
          'geo:52.52,13.405?q=Berlin');
    });

    test('vCard contains the standard fields', () {
      final payload = QrData.vCard(
        name: 'Dana Deaa',
        firstName: 'Dana',
        lastName: 'Deaa',
        organization: 'Light, Code;GmbH',
        mobile: '+1234567890',
        email: 'dana@example.com',
        website: 'https://example.com',
      );
      expect(payload, startsWith('BEGIN:VCARD'));
      expect(payload, contains('VERSION:3.0'));
      expect(payload, contains('FN:Dana Deaa'));
      expect(payload, contains('N:Deaa;Dana;;;'));
      expect(payload, contains(r'ORG:Light\, Code\;GmbH'));
      expect(payload, contains('TEL;TYPE=CELL:+1234567890'));
      expect(payload, contains('EMAIL:dana@example.com'));
      expect(payload.trim(), endsWith('END:VCARD'));
    });

    test('event uses iCalendar UTC timestamps', () {
      final payload = QrData.event(
        title: 'Launch',
        start: DateTime.utc(2026, 8, 1, 9, 30),
        end: DateTime.utc(2026, 8, 1, 10, 0),
        location: 'Online',
      );
      expect(payload, contains('DTSTART:20260801T093000Z'));
      expect(payload, contains('DTEND:20260801T100000Z'));
      expect(payload, contains('SUMMARY:Launch'));
    });

    test('payloads encode and decode round-trip', () {
      final payloads = [
        QrData.wifi(ssid: 'Cafe', password: 'espresso42'),
        QrData.email(to: 'a@b.co', subject: 'S'),
        QrData.sms(phone: '+15550001111', message: 'Hey'),
        QrData.phone('+15550001111'),
        QrData.whatsapp(phone: '15550001111', text: 'Hi'),
        QrData.geo(latitude: 1.5, longitude: -2.25),
        QrData.vCard(name: 'A B', email: 'a@b.co'),
        QrData.event(title: 'E', start: DateTime.utc(2026, 1, 1)),
      ];
      for (final payload in payloads) {
        final code = QrCode.encode(payload);
        expect(decodeWithZxing(code), payload,
            reason: 'payload failed: $payload');
      }
    });
  });
}
