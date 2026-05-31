// @ts-check

/**
 * Per-arg primitives for image-typed args. The chrome uses these to
 * decide which empty-state overlays to paint, which drop targets to
 * register, and which replace menus to open. Stays a pure module — no
 * service reads, no DOM — so it can be unit-tested with plain JS
 * fixtures.
 *
 * Supports multi-image blocks (e.g. `wf:media-card` with both an
 * avatar and a cover image) and the inline editing affordances on the
 * first-class `image` arg type.
 */

/**
 * Returns an array of image arg entries declared on the schema, in
 * declaration order. Each entry carries enough metadata for the chrome
 * to decide what overlay to paint:
 *
 *   - `name`: the arg name as it appears under `entry.args`
 *   - `def`: the raw schema entry (capability flags, ui hints, …)
 *   - `value`: the live value, or `undefined` when unset
 *   - `isEmpty`: `true` when no `url` is set (treats nullish and
 *     `{ width, height }` without `url` as empty)
 *
 * @param {Object|null|undefined} argsSchema - The block's args schema
 *   (the `args` field on block metadata, keyed by arg name).
 * @param {Object|null|undefined} liveArgs - The entry's live args
 *   object, keyed by arg name.
 * @returns {Array<{name: string, def: Object, value: any, isEmpty: boolean}>}
 */
export function imageArgEntries(argsSchema, liveArgs) {
  if (!argsSchema || typeof argsSchema !== "object") {
    return [];
  }
  const args = liveArgs ?? {};
  const out = [];
  for (const [name, def] of Object.entries(argsSchema)) {
    if (def?.type !== "image") {
      continue;
    }
    const value = args[name];
    out.push({ name, def, value, isEmpty: isImageArgValueEmpty(value) });
  }
  return out;
}

/**
 * Returns `true` when the given image-arg value has no usable `url`.
 * Matches the gate every image-bearing block uses in its template
 * (`{{#if @image.url}}`), so the chrome's empty-state decision agrees
 * with what the renderer actually paints.
 *
 * @param {any} value
 * @returns {boolean}
 */
export function isImageArgValueEmpty(value) {
  if (!value || typeof value !== "object") {
    return true;
  }
  return typeof value.url !== "string" || value.url.length === 0;
}

/**
 * Convenience boolean predicate: `true` when the schema declares one or
 * more image args AND every one of them is empty. Keyed off the
 * arg's `type: "image"`.
 *
 * @param {Object|null|undefined} argsSchema
 * @param {Object|null|undefined} liveArgs
 * @returns {boolean}
 */
export function entryHasOnlyEmptyImageArgs(argsSchema, liveArgs) {
  const entries = imageArgEntries(argsSchema, liveArgs);
  if (entries.length === 0) {
    return false;
  }
  return entries.every((e) => e.isEmpty);
}
