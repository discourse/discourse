import type { RpcRequest } from "discourse/data/builders/helpers";
import { deleteOne } from "discourse/data/builders/helpers";

export function deleteBookmark(id: string | number) {
  return deleteOne("bookmark", id, `/bookmarks/${encodeURIComponent(id)}.json`);
}

export function togglePinBookmark(id: string | number): RpcRequest {
  return {
    url: `/bookmarks/${encodeURIComponent(id)}/toggle_pin`,
    method: "PUT",
  };
}

// `operation` is passed through as the body.
export function bulkBookmarkOperation(
  bookmarkIds: Array<string | number>,
  operation: string | { type: string; [arg: string]: unknown }
): RpcRequest {
  return {
    url: `/bookmarks/bulk`,
    method: "PUT",
    options: { body: { bookmark_ids: bookmarkIds, operation } },
  };
}
