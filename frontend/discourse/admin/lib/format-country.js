import I18n from "discourse-i18n";

export function countryFlag(code) {
  if (!code || code.length !== 2) {
    return "";
  }
  const upper = code.toUpperCase();
  const offset = 0x1f1e6 - "A".charCodeAt(0);
  return (
    String.fromCodePoint(offset + upper.charCodeAt(0)) +
    String.fromCodePoint(offset + upper.charCodeAt(1))
  );
}

export function countryName(code) {
  if (!code) {
    return "";
  }
  try {
    const locale = I18n.currentBcp47Locale || "en";
    const displayName = new Intl.DisplayNames([locale], { type: "region" }).of(
      code
    );
    return displayName || code;
  } catch {
    return code;
  }
}
