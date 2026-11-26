/**
 * The origin of a blog URL, or `null` when the URL is missing or unusable.
 *
 * @param {string} url - A blog's base URL from the site data.
 * @returns {string|null}
 */
export default function blogOrigin(url) {
  try {
    return new URL(url).origin;
  } catch {
    return null;
  }
}

/**
 * The origin of the blog page an embedded discussion is shown on. Several
 * blogs can embed discussions, so the frame's referrer decides between them.
 *
 * @param {Array<{base_url: string}>} blogs - The blogs from the site data.
 * @param {string} referrer - The URL of the page that loaded the frame.
 * @returns {string|null} `null` when no blog can be told apart.
 */
export function embeddingBlogOrigin(blogs, referrer) {
  const origins = [
    ...new Set((blogs || []).map((blog) => blogOrigin(blog.base_url))),
  ].filter(Boolean);
  const referrerOrigin = blogOrigin(referrer);
  if (origins.includes(referrerOrigin)) {
    return referrerOrigin;
  }
  return origins.length === 1 ? origins[0] : null;
}
