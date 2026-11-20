import cookie from "discourse/lib/cookie";

export const AUTOMATICALLY_TRANSLATE_COOKIE = "automatically_translate";
export const AUTOMATICALLY_TRANSLATE_COOKIE_EXPIRY = 30;
export const LOCALE_COOKIE = "locale";
export const LOCALE_COOKIE_EXPIRY = 365;

export function interfaceLocaleOptions(
  siteSettings,
  locales = siteSettings.available_locales ?? []
) {
  const policy = siteSettings.allowed_user_locales ?? "all";
  if (policy === "all") {
    return locales;
  }
  const allowed = policy === "none" ? [] : policy.split("|");
  return locales.filter(
    ({ value }) =>
      value === siteSettings.default_locale || allowed.includes(value)
  );
}

export function languageSwitcherLocales(siteSettings) {
  return interfaceLocaleOptions(
    siteSettings,
    siteSettings.available_content_localization_locales ?? []
  );
}

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
    siteSettings.content_localization_language_switcher !== "none" &&
    !!siteSettings.content_localization_supported_locales &&
    languageSwitcherLocales(siteSettings).length > 1
  );
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
