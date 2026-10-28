/**
 * The origin of the configured blog, or `null` when the setting is missing or unusable.
 *
 * @param {string} url - `blog_url`, normally without a trailing slash or path.
 * @returns {string|null}
 */
export default function blogOrigin(url) {
  try {
    return new URL(url).origin;
  } catch {
    return null;
  }
}
