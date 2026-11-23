import type { RpcRequest } from "discourse/data/builders/helpers";
import { deleteOne } from "discourse/data/builders/helpers";
import type { WarpResourceId } from "discourse/data/warp-rest-model";

export function deleteBookmark(id: WarpResourceId) {
  return deleteOne("bookmark", id, `/bookmarks/${encodeURIComponent(id)}.json`);
}

export function togglePinBookmark(id: WarpResourceId): RpcRequest {
  return {
    url: `/bookmarks/${encodeURIComponent(id)}/toggle_pin`,
    method: "PUT",
  };
}

export function bulkBookmarkOperation(
  bookmarkIds: WarpResourceId[],
  operation: string | { type: string; [arg: string]: unknown }
): RpcRequest {
  return {
    url: `/bookmarks/bulk`,
    method: "PUT",
    options: { body: { bookmark_ids: bookmarkIds, operation } },
  };
}
