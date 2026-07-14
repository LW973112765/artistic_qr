/// Ready-made payload builders for the QR content types people actually
/// scan: WiFi credentials, contact cards, WhatsApp chats, emails, SMS,
/// phone numbers, locations, and calendar events.
///
/// ```dart
/// ArtisticQrCode(
///   data: QrData.wifi(ssid: 'CoffeeShop', password: 'espresso42'),
/// )
/// ```
library;

/// WiFi authentication type for [QrData.wifi].
enum QrWifiSecurity {
  wpa('WPA'),
  wep('WEP'),
  none('nopass');

  const QrWifiSecurity(this.token);
  final String token;
}

abstract final class QrData {
  /// `WIFI:` payload — scanning joins the network directly.
  static String wifi({
    required String ssid,
    String? password,
    QrWifiSecurity security = QrWifiSecurity.wpa,
    bool hidden = false,
  }) {
    assert(security == QrWifiSecurity.none || password != null,
        'WPA/WEP networks need a password');
    final b = StringBuffer('WIFI:T:${security.token};S:${_escapeWifi(ssid)};');
    if (security != QrWifiSecurity.none && password != null) {
      b.write('P:${_escapeWifi(password)};');
    }
    if (hidden) b.write('H:true;');
    b.write(';');
    return b.toString();
  }

  /// `mailto:` payload — opens a pre-filled email draft.
  static String email({
    required String to,
    String? subject,
    String? body,
    String? cc,
  }) {
    final params = <String, String>{
      'subject': ?subject,
      'body': ?body,
      'cc': ?cc,
    };
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: params.isEmpty ? null : params,
    );
    return uri.toString();
  }

  /// `SMSTO:` payload — opens the SMS composer.
  static String sms({required String phone, String? message}) =>
      message == null || message.isEmpty
          ? 'SMSTO:${_cleanPhone(phone)}'
          : 'SMSTO:${_cleanPhone(phone)}:$message';

  /// `tel:` payload — starts a phone call.
  static String phone(String number) => 'tel:${_cleanPhone(number)}';

  /// WhatsApp deep link — opens a chat, optionally pre-filled with [text].
  static String whatsapp({required String phone, String? text}) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final query = text == null || text.isEmpty
        ? ''
        : '?text=${Uri.encodeComponent(text)}';
    return 'https://wa.me/$digits$query';
  }

  /// `geo:` payload — opens the location in the maps app.
  static String geo({
    required double latitude,
    required double longitude,
    String? query,
  }) {
    assert(latitude >= -90 && latitude <= 90);
    assert(longitude >= -180 && longitude <= 180);
    final base = 'geo:$latitude,$longitude';
    return query == null ? base : '$base?q=${Uri.encodeComponent(query)}';
  }

  /// vCard 3.0 payload — adds a contact with one scan.
  static String vCard({
    required String name,
    String? firstName,
    String? lastName,
    String? organization,
    String? title,
    String? phone,
    String? mobile,
    String? email,
    String? website,
    String? address,
    String? note,
  }) {
    final b = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('FN:${_escapeVCard(name)}');
    if (firstName != null || lastName != null) {
      b.writeln('N:${_escapeVCard(lastName ?? '')};'
          '${_escapeVCard(firstName ?? '')};;;');
    }
    if (organization != null) b.writeln('ORG:${_escapeVCard(organization)}');
    if (title != null) b.writeln('TITLE:${_escapeVCard(title)}');
    if (phone != null) b.writeln('TEL;TYPE=WORK,VOICE:${_cleanPhone(phone)}');
    if (mobile != null) b.writeln('TEL;TYPE=CELL:${_cleanPhone(mobile)}');
    if (email != null) b.writeln('EMAIL:${_escapeVCard(email)}');
    if (website != null) b.writeln('URL:${_escapeVCard(website)}');
    if (address != null) b.writeln('ADR;TYPE=WORK:;;${_escapeVCard(address)};;;;');
    if (note != null) b.writeln('NOTE:${_escapeVCard(note)}');
    b.writeln('END:VCARD');
    return b.toString();
  }

  /// iCalendar VEVENT payload — adds an event to the calendar.
  static String event({
    required String title,
    required DateTime start,
    DateTime? end,
    String? location,
    String? description,
  }) {
    final b = StringBuffer()
      ..writeln('BEGIN:VEVENT')
      ..writeln('SUMMARY:${_escapeVCard(title)}')
      ..writeln('DTSTART:${_icalDate(start)}');
    if (end != null) b.writeln('DTEND:${_icalDate(end)}');
    if (location != null) b.writeln('LOCATION:${_escapeVCard(location)}');
    if (description != null) {
      b.writeln('DESCRIPTION:${_escapeVCard(description)}');
    }
    b.writeln('END:VEVENT');
    return b.toString();
  }

  /// Escapes `\`, `;`, `,`, `"` and `:` per the WIFI: syntax.
  static String _escapeWifi(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('"', r'\"')
      .replaceAll(':', r'\:');

  /// Escapes `\`, `;`, `,` and newlines per RFC 6350.
  static String _escapeVCard(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\n', r'\n');

  /// Keeps digits and a leading `+`.
  static String _cleanPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final plus = cleaned.startsWith('+') ? '+' : '';
    return plus + cleaned.replaceAll('+', '');
  }

  /// UTC timestamp in iCalendar basic format (yyyyMMddTHHmmssZ).
  static String _icalDate(DateTime time) {
    final utc = time.toUtc();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${utc.year}${p2(utc.month)}${p2(utc.day)}'
        'T${p2(utc.hour)}${p2(utc.minute)}${p2(utc.second)}Z';
  }
}
