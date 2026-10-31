int? parsePriceToCents(String raw) {
  final trimmed = raw.trim();
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(trimmed);
  if (match == null) {
    return null;
  }
  final major = int.parse(match.group(1)!);
  final minorRaw = match.group(2);
  final minor = minorRaw == null ? 0 : int.parse(minorRaw.padRight(2, '0'));
  return major * 100 + minor;
}
