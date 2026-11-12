// Reads the Web Share Target payload that the service worker stashed in the
// Cache API before redirecting to the `share-target` route. Keep these
// constants in sync with app/views/static/service-worker.js.erb.
const SHARE_TARGET_CACHE = "discourse-share-target";
const SHARE_TARGET_KEY_PREFIX = "/__discourse_share_target__/";

export async function readSharedContent() {
  if (typeof caches === "undefined") {
    return null;
  }

  let cache;
  try {
    cache = await caches.open(SHARE_TARGET_CACHE);
  } catch {
    return null;
  }

  const metaResponse = await cache.match(
    new Request(SHARE_TARGET_KEY_PREFIX + "meta")
  );

  if (!metaResponse) {
    return null;
  }

  const meta = await metaResponse.json();

  const files = [];
  for (const fileMeta of meta.files || []) {
    const fileResponse = await cache.match(new Request(fileMeta.key));
    if (!fileResponse) {
      continue;
    }

    const blob = await fileResponse.blob();
    const name = decodeURIComponent(
      fileResponse.headers.get("x-share-filename") ||
        fileMeta.name ||
        "shared-file"
    );

    files.push(new File([blob], name, { type: fileMeta.type || blob.type }));
  }

  return {
    title: meta.title || "",
    text: meta.text || "",
    url: meta.url || "",
    files,
  };
}

export async function clearSharedContent() {
  if (typeof caches === "undefined") {
    return;
  }

  try {
    await caches.delete(SHARE_TARGET_CACHE);
  } catch {
    // nothing to clear
  }
}

// Combines the shared text and url into a single composer body.
export function sharedBody({ text, url } = {}) {
  return [text, url].filter(Boolean).join("\n\n");
}
