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
 * @param {Object} siteSettings - the siteSettings service
 * @returns {boolean}
 */
export function languageSwitcherEnabled(siteSettings) {
  return (
    siteSettings.content_localization_enabled &&
    siteSettings.allow_user_locale &&
    siteSettings.content_localization_language_switcher !== "none" &&
    !!siteSettings.content_localization_supported_locales
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
