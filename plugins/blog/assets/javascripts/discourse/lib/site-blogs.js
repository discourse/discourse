/**
 * The default blog from the site data.
 *
 * @param {Object} site - The site service.
 * @returns {Object|undefined}
 */
export function defaultBlog(site) {
  return site.blogs?.find((blog) => blog.is_default);
}

/**
 * A blog from the site data by id, given as a number or a query param string.
 *
 * @param {Object} site - The site service.
 * @param {number|string} id - The blog's id.
 * @returns {Object|undefined}
 */
export function findBlog(site, id) {
  return site.blogs?.find((blog) => String(blog.id) === String(id));
}

/**
 * Keeps the site's blogs current after an admin saves one, so the editor's
 * "New draft" menu and blog filter need no reload.
 *
 * @param {Object} site - The site service.
 * @param {Object} blog - The blog as the admin endpoints return it.
 */
export function storeSiteBlog(site, blog) {
  const entry = {
    id: blog.id,
    name: blog.name,
    base_url: blog.base_url,
    category_id: blog.category_id,
    path_format: blog.path_format,
    is_default: blog.is_default,
  };
  const blogs = site.blogs || [];
  const known = blogs.some((candidate) => candidate.id === blog.id);
  site.set(
    "blogs",
    known
      ? blogs.map((candidate) => (candidate.id === blog.id ? entry : candidate))
      : [...blogs, entry]
  );
}

/**
 * @param {Object} site - The site service.
 * @param {number} id - The deleted blog's id.
 */
export function removeSiteBlog(site, id) {
  site.set(
    "blogs",
    (site.blogs || []).filter((candidate) => candidate.id !== id)
  );
}
