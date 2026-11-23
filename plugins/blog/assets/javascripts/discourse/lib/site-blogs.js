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
