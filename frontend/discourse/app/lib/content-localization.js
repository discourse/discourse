import cookie from "discourse/lib/cookie";

export const AUTOMATICALLY_TRANSLATE_COOKIE = "automatically_translate";
export const AUTOMATICALLY_TRANSLATE_COOKIE_EXPIRY = 30;
export const LOCALE_COOKIE = "locale";
export const LOCALE_COOKIE_EXPIRY = 365;

/**
 * Whether the site offers anonymous visitors a way to pick their own locale.
 *
 * Mirrors `ContentLocalization.language_switcher_enabled?` server-side, which is what decides
 * whether the `locale` cookie is honoured. Keep the two in sync: a cookie that is honoured
 * without the corresponding UI leaves visitors stuck in a locale they cannot change back.
 *
 * @param {{ content_localization_enabled: boolean, allowed_user_locales: string, content_localization_language_switcher: string, content_localization_supported_locales: string }} siteSettings - the siteSettings service
 * @returns {boolean}
 */
export function languageSwitcherEnabled(siteSettings) {
  return (
    siteSettings.content_localization_enabled &&
    !!siteSettings.allowed_user_locales &&
    siteSettings.content_localization_language_switcher !== "none" &&
    !!siteSettings.content_localization_supported_locales
  );
}

export function interfaceLanguageOptions(
  siteSettings,
  locales = siteSettings.available_locales,
  currentLocale
) {
  const allowed = siteSettings.allowed_user_locales ?? "all";
  if (allowed === "all") {
    return locales ?? [];
  }

  const values = new Set([
    ...allowed.split("|").filter(Boolean),
    siteSettings.default_locale,
    currentLocale,
  ]);
  return (locales ?? []).filter(({ value }) => values.has(value));
}

export function normalizeAllowedUserLocales(values, previousValues) {
  if (values.includes("all") && values.length > 1) {
    return previousValues.includes("all")
      ? values.filter((value) => value !== "all")
      : ["all"];
  }
  return values;
}

export function normalizeUnderstoodLanguages(languages) {
  return [...new Set((languages ?? []).filter(Boolean))];
}

export function automaticallyTranslate(currentUser) {
  if (currentUser) {
    return currentUser.user_option?.automatically_translate ?? true;
  }

  return cookie(AUTOMATICALLY_TRANSLATE_COOKIE) !== "false";
}
