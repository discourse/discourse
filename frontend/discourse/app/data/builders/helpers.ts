import type {
  Normalizer,
  WarpRequest,
  WarpResourceId,
} from "discourse/data/warp-rest-model";

/** An RPC-style request; the cache applies no operation for it. */
export type RpcRequest = Omit<WarpRequest, "op" | "data">;

// CRUD shorthands for per-resource builders. RPC-style endpoints (toggles,
// notification updates, remove-allowed-X) skip these and use plain inline
// request objects — they don't fit the CRUD shape.

export function readMany(url: string, normalize: Normalizer): WarpRequest {
  return { url, method: "GET", op: "query", options: { normalize } };
}

export function readOne(url: string, normalize: Normalizer): WarpRequest {
  return { url, method: "GET", op: "findRecord", options: { normalize } };
}

export function createOne(
  url: string,
  body: unknown,
  normalize: Normalizer
): WarpRequest {
  return {
    url,
    method: "POST",
    op: "createRecord",
    options: { body, normalize },
  };
}

export function updateOne(
  type: string,
  id: WarpResourceId,
  url: string,
  body: unknown,
  normalize: Normalizer
): WarpRequest {
  return {
    url,
    method: "PUT",
    op: "updateRecord",
    data: { type, id: String(id) },
    options: { body, normalize },
  };
}

export function deleteOne(
  type: string,
  id: WarpResourceId,
  url: string
): WarpRequest {
  return {
    url,
    method: "DELETE",
    op: "deleteRecord",
    data: { type, id: String(id) },
  };
}
