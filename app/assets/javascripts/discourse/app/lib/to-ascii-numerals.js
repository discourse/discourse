/*
Converts Arabic-Indic (٠١٢٣٤٥٦٧٨٩) and
Eastern Arabic-Indic (۰۱۲۳۴۵۶۷۸۹, Persian/Urdu)
into Western Arabic digits (0123456789).

Runs conversion only if non-ASCII digits are present.
Related ChatGPT Converseation: https://chatgpt.com/share/68c2c5f2-ba7c-8004-8d53-6b2db78a20b5

*/

const DIGIT_MAP = {
  "٠": "0",
  "١": "1",
  "٢": "2",
  "٣": "3",
  "٤": "4",
  "٥": "5",
  "٦": "6",
  "٧": "7",
  "٨": "8",
  "٩": "9",
  "۰": "0",
  "۱": "1",
  "۲": "2",
  "۳": "3",
  "۴": "4",
  "۵": "5",
  "۶": "6",
  "۷": "7",
  "۸": "8",
  "۹": "9",
};

const NON_ASCII_DIGITS = /[٠-٩۰-۹]/; // regex check

export default function toASCIIDigits(str) {
  if (!NON_ASCII_DIGITS.test(str)) {
    return str; // fast path, no conversion needed
  }
  return str
    .split("")
    .map((ch) => DIGIT_MAP[ch] || ch)
    .join("");
}
