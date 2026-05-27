import { i18n } from "discourse-i18n";

export function i18nForOwner(key, isOwner, options = {}) {
  const suffix = isOwner ? "" : "_others";
  return i18n(`${key}${suffix}`, options);
}
