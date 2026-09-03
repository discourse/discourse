import I18n from "discourse-i18n";

export function languageName(language) {
  if (!language) {
    return "";
  }

  try {
    const locale = I18n.currentBcp47Locale || "en";
    return (
      new Intl.DisplayNames([locale], { type: "language" }).of(language) ||
      language
    );
  } catch {
    return language;
  }
}
