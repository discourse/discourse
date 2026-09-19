/**
 * Two locales are the same when they are equal or share the same base language,
 * ignoring region and separator/case differences, e.g. `en_GB` and `en`, or
 * `zh-TW` and `zh_CN`. A blank locale never matches.
 *
 * @param {string} locale1
 * @param {string} locale2
 * @returns {boolean}
 */
export function isSameLocale(locale1, locale2) {
  if (!locale1 || !locale2) {
    return false;
  }

  const base = (locale) => locale.toLowerCase().split(/[-_]/)[0];

  return base(locale1) === base(locale2);
}
