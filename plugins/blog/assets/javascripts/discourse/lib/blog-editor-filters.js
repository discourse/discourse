import { i18n } from "discourse-i18n";

export const STATUS_OPTIONS = [
  { value: "all", label: i18n("blog.all") },
  { value: "drafts", label: i18n("blog.drafts") },
  { value: "published", label: i18n("blog.published") },
  { value: "unpublished", label: i18n("blog.not_published") },
];

// The server rejects longer queries.
const MAX_QUERY_LENGTH = 100;

export function editorFilters({ status, q } = {}) {
  return {
    filter: STATUS_OPTIONS.some((option) => option.value === status)
      ? status
      : "all",
    q: (q || "").trim().slice(0, MAX_QUERY_LENGTH),
  };
}
