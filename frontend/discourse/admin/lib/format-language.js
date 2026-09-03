import I18n from "discourse-i18n";

export function languageName(language) {
  if (!language) {
    return "";
  }

  try {
    const locale = I18n.currentBcp47Locale || "en";
    const languageLocale = new Intl.Locale(language);
    const name = new Intl.DisplayNames([locale], { type: "language" }).of(
      languageLocale.language
    );
    const region =
      languageLocale.region === "GB" ? "UK" : languageLocale.region;
    const script = languageLocale.script
      ? new Intl.DisplayNames([locale], { type: "script" }).of(
          languageLocale.script
        )
      : null;
    const qualifiers = [script, region].filter(Boolean);

    return qualifiers.length
      ? `${name} (${qualifiers.join(", ")})`
      : name || language;
  } catch {
    return language;
  }
}
