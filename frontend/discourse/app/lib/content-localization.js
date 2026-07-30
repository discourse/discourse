import cookie from "discourse/lib/cookie";

export const AUTOMATICALLY_TRANSLATE_COOKIE = "automatically_translate";
export const AUTOMATICALLY_TRANSLATE_COOKIE_EXPIRY = 30;

export function normalizeUnderstoodLanguages(languages, interfaceLanguage) {
  return [
    ...new Set([interfaceLanguage, ...(languages ?? [])].filter(Boolean)),
  ];
}

export function automaticallyTranslate(currentUser) {
  if (currentUser) {
    return currentUser.user_option?.automatically_translate ?? true;
  }

  return cookie(AUTOMATICALLY_TRANSLATE_COOKIE) !== "false";
}
