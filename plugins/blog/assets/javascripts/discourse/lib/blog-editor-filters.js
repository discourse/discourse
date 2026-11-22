import { i18n } from "discourse-i18n";

export const STATUS_OPTIONS = [
  { value: "all", label: i18n("blog.all") },
  { value: "drafts", label: i18n("blog.drafts") },
  { value: "published", label: i18n("blog.published") },
  { value: "unpublished", label: i18n("blog.not_published") },
  { value: "pages", label: i18n("blog.pages") },
];

// The server rejects longer queries.
const MAX_QUERY_LENGTH = 100;

/**
 * The editor list filters from query params, dropping values the server would reject.
 *
 * @param {Object} params - The `status`, `q` and `blog` query params.
 * @param {Array<{id: number}>} [blogs] - The site's blogs; a blog filter must name one.
 * @returns {{filter: string, q: string, blog?: string}}
 */
export function editorFilters({ status, q, blog } = {}, blogs = null) {
  const filters = {
    filter: STATUS_OPTIONS.some((option) => option.value === status)
      ? status
      : "all",
    q: (q || "").trim().slice(0, MAX_QUERY_LENGTH),
  };
  const known =
    !blogs || blogs.some((candidate) => String(candidate.id) === blog);
  if (/^\d+$/.test(blog || "") && known) {
    filters.blog = blog;
  }
  return filters;
}
