class Character {
  static bool isIsoControl(int rune) {
    return (rune >= 0x00 && rune <= 0x1F) || (rune >= 0x7F && rune <= 0x9F);
  }

  static bool isWhitespace(int rune) {
    return (rune >= 0x0009 && rune <= 0x000D) ||
        rune == 0x0020 ||
        rune == 0x0085 ||
        rune == 0x00A0 ||
        rune == 0x1680 ||
        rune == 0x180E ||
        (rune >= 0x2000 && rune <= 0x200A) ||
        rune == 0x2028 ||
        rune == 0x2029 ||
        rune == 0x202F ||
        rune == 0x205F ||
        rune == 0x3000 ||
        rune == 0xFEFF;
  }
}
