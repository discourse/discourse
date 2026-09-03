// CRUD shorthands for per-resource builders. RPC-style endpoints (toggles,
// notification updates, remove-allowed-X) skip these and use plain inline
// request objects — they don't fit the CRUD shape.

export function readMany(url, normalize) {
  return { url, method: "GET", op: "query", options: { normalize } };
}

export function readOne(url, normalize) {
  return { url, method: "GET", op: "findRecord", options: { normalize } };
}

export function createOne(url, body, normalize) {
  return {
    url,
    method: "POST",
    op: "createRecord",
    options: { body, normalize },
  };
}

export function updateOne(type, id, url, body, normalize) {
  return {
    url,
    method: "PUT",
    op: "updateRecord",
    data: { type, id: String(id) },
    options: { body, normalize },
  };
}

export function deleteOne(type, id, url) {
  return {
    url,
    method: "DELETE",
    op: "deleteRecord",
    data: { type, id: String(id) },
  };
}
