import { deleteOne } from "discourse/data/builders/helpers";

export function deleteBookmark(id) {
  return deleteOne("bookmark", id, `/bookmarks/${encodeURIComponent(id)}.json`);
}

export function togglePinBookmark(id) {
  return {
    url: `/bookmarks/${encodeURIComponent(id)}/toggle_pin`,
    method: "PUT",
  };
}

// `operation` is a `{ type, ...args }` object passed through as the body.
export function bulkBookmarkOperation(bookmarkIds, operation) {
  return {
    url: `/bookmarks/bulk`,
    method: "PUT",
    options: { body: { bookmark_ids: bookmarkIds, operation } },
  };
}
