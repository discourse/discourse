/**
 * The origin of the configured blog, or `null` when the setting is missing or unusable.
 *
 * @param {string} url - The blog's base URL from the site data.
 * @returns {string|null}
 */
export default function blogOrigin(url) {
  try {
    return new URL(url).origin;
  } catch {
    return null;
  }
}
