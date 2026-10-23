import { deleteOne } from "discourse/data/builders/helpers";
import type { WarpRequest } from "discourse/data/warp-rest-model";

export function deleteBookmark(id: string | number) {
  return deleteOne("bookmark", id, `/bookmarks/${encodeURIComponent(id)}.json`);
}

export function togglePinBookmark(id: string | number): WarpRequest {
  return {
    url: `/bookmarks/${encodeURIComponent(id)}/toggle_pin`,
    method: "PUT",
  };
}

// `operation` is a `{ type, ...args }` object passed through as the body.
export function bulkBookmarkOperation(
  bookmarkIds: Array<string | number>,
  operation: { type: string; [arg: string]: unknown }
): WarpRequest {
  return {
    url: `/bookmarks/bulk`,
    method: "PUT",
    options: { body: { bookmark_ids: bookmarkIds, operation } },
  };
}
