import 'package:number_to_indian_words/number_to_indian_words.dart';

String amountInIndianWords(num value) {
  final intPart = value.floor();
  final paise = ((value - intPart) * 100).round();
  final rupeesWords = NumToWords.convertNumberToIndianWords(intPart); // 354000 → “Three Lakh Fifty Four Thousand” [web:800]
  if (paise > 0) {
    final paiseWords = NumToWords.convertNumberToIndianWords(paise); // 75 → “Seventy Five” [web:800]
    return '$rupeesWords rupees and $paiseWords paise only'; // Currency phrasing [web:800]
  }
  return '$rupeesWords rupees only'; // No paise [web:800]
}
