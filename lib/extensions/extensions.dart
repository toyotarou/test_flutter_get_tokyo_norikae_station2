import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

extension ContextEx on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorTheme => Theme.of(this).colorScheme;

  Size get screenSize => MediaQuery.of(this).size;

  void showKeyboard(FocusNode node) {
    FocusScope.of(this).requestFocus(node);
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }
}

extension DateTimeEx on DateTime {
  String get yyyymmdd {
    final DateFormat outputFormat = DateFormat('yyyy-MM-dd');
    return outputFormat.format(this);
  }

  String get yyyymm {
    final DateFormat outputFormat = DateFormat('yyyy-MM');
    return outputFormat.format(this);
  }

  String get mmdd {
    final DateFormat outputFormat = DateFormat('MM-dd');
    return outputFormat.format(this);
  }

  String get yyyy {
    final DateFormat outputFormat = DateFormat('yyyy');
    return outputFormat.format(this);
  }

  String get mm {
    final DateFormat outputFormat = DateFormat('MM');
    return outputFormat.format(this);
  }

  String get dd {
    final DateFormat outputFormat = DateFormat('dd');
    return outputFormat.format(this);
  }

  String get youbiStr {
    final DateFormat outputFormat = DateFormat('EEEE');
    return outputFormat.format(this);
  }

  // ===== ここから追記：日付比較を“日単位”で扱うためのヘルパ =====

  /// 時刻を切り捨てた "日付のみ"（00:00:00）を返す
  DateTime get dateOnly => DateTime(year, month, day);

  /// 同じ日付か（時刻は無視）
  bool isSameDate(DateTime other) => dateOnly.isAtSameMomentAs(other.dateOnly);

  /// 厳密に「前の日付」か（<、同日は含まない）
  bool isBeforeDate(DateTime other) => dateOnly.isBefore(other.dateOnly);

  /// 厳密に「後の日付」か（>、同日は含まない）
  bool isAfterDate(DateTime other) => dateOnly.isAfter(other.dateOnly);

  /// 「前または同じ日付」か（<=）
  bool isBeforeOrSameDate(DateTime other) => isBeforeDate(other) || isSameDate(other);

  /// 「後または同じ日付」か（>=）
  bool isAfterOrSameDate(DateTime other) => isAfterDate(other) || isSameDate(other);

  /// 範囲内かどうか（閉区間: start <= this <= end）
  bool isBetweenDatesInclusive(DateTime start, DateTime end) => isAfterOrSameDate(start) && isBeforeOrSameDate(end);

  /// 範囲内かどうか（開区間: start < this < end）
  bool isBetweenDatesExclusive(DateTime start, DateTime end) => isAfterDate(start) && isBeforeDate(end);

  // ===== 追記ここまで =====
}

const int _fullLengthCode = 65248;

extension StringEx on String {
  DateTime toDateTime() {
    final DateFormat dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return dateFormatter.parseStrict(this);
  }

  int toInt() {
    return int.parse(this);
  }

  String toCurrency() {
    final NumberFormat formatter = NumberFormat('#,###');
    return formatter.format(int.parse(this));
  }

  double toDouble() {
    return double.parse(this);
  }

  String alphanumericToFullLength() {
    final RegExp regex = RegExp(r'^[a-zA-Z0-9]+$');
    final Iterable<String> string = runes.map<String>((int rune) {
      final String char = String.fromCharCode(rune);
      return regex.hasMatch(char) ? String.fromCharCode(rune + _fullLengthCode) : char;
    });
    return string.join();
  }

  String alphanumericToHalfLength() {
    final RegExp regex = RegExp(r'^[Ａ-Ｚａ-ｚ０-９]+$');
    final Iterable<String> string = runes.map<String>((int rune) {
      final String char = String.fromCharCode(rune);
      return regex.hasMatch(char) ? String.fromCharCode(rune - _fullLengthCode) : char;
    });
    return string.join();
  }
}

// ignore: strict_raw_type, always_specify_types
extension ListIndexCheck on List {
  bool isInRange(int i) => i >= 0 && i < length;
}
