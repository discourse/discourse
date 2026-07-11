// @ts-check
/**
 * Composite block support
 *
 * A block may declare a code-defined inner composition via the `parts` option
 * (see the `@block` decorator). When an entry referencing such a block supplies
 * no `children` of its own, the block renders its parts: each part is an inner
 * block, addressed by a stable `id`, carrying default `args`. An instance may
 * override a part's own args by part id, except args the part marks locked.
 *
 * The parts are *synthesized* into render-only child entries at walk time (both
 * the render walk and the data-prefetch walk), never written back onto the
 * persisted entry. This module holds the pure rules they share: the override
 * path scheme, the lock filter, the default⊕override merge, and the synthesis
 * itself. Synthesis reads markers off the entry it is given, so the ordinary
 * child-walk recursion handles arbitrarily nested compositions with no special
 * casing.
 *
 * @module discourse/lib/blocks/-internals/composite
 */

/**
 * Separator embedded in a synthesized part's stable key, between the composite
 * instance's key and a part id. Repeats for each nesting level, e.g.
 * `42::part::action::part::label`.
 *
 * @constant {string}
 */
export const PART_KEY_SEGMENT = "::part::";

/**
 * Joins id-path segments into a dot-delimited override-path key
 * (e.g. `["action", "label"]` → `"action.label"`). Empty/nullish segments are
 * dropped, so `joinPartPath("", "title")` is `"title"`.
 *
 * @param {...(string|null|undefined)} segments
 * @returns {string}
 */
export function joinPartPath(...segments) {
  return segments.filter((s) => s != null && s !== "").join(".");
}

/**
 * Splits a dot-delimited override path into its id segments. An empty/nullish
 * path yields an empty array.
 *
 * @param {string|null|undefined} path
 * @returns {string[]}
 */
export function splitPartPath(path) {
  return path ? path.split(".") : [];
}

/**
 * Returns true when a stable key belongs to a synthesized part (i.e. it
 * encodes a composite instance and an id path).
 *
 * @param {*} stableKey
 * @returns {boolean}
 */
export function isPartKey(stableKey) {
  return typeof stableKey === "string" && stableKey.includes(PART_KEY_SEGMENT);
}

/**
 * Parses a synthesized part's stable key into the owning composite instance's
 * key and the id path beneath it.
 *
 * `"42::part::action::part::label"` → `{ compositeKey: "42", idPath: ["action",
 * "label"] }`. The `compositeKey` is the persisted composite entry's own
 * `__stableKey` (a number, returned here as its string form); the id path
 * addresses the part beneath it and matches the persisted override key
 * (`action.label`).
 *
 * @param {string} stableKey
 * @returns {{compositeKey: string, idPath: string[]}|null}
 */
export function parsePartKey(stableKey) {
  if (!isPartKey(stableKey)) {
    return null;
  }
  const segments = stableKey.split(PART_KEY_SEGMENT);
  return { compositeKey: segments[0], idPath: segments.slice(1) };
}

/**
 * Splits a composite's flat, path-keyed overrides into the slice that applies
 * to one part: the part's own args (the entry keyed exactly by `id`) and the
 * deeper overrides for that part's descendants (keys prefixed by `${id}.`,
 * with the prefix stripped so the next synthesis level sees them as top-level).
 *
 * @param {Object|null|undefined} overrides - The composite's path-keyed overrides.
 * @param {string} id - The part id.
 * @returns {{own: Object|undefined, nested: Object|undefined}}
 */
export function childOverridesFor(overrides, id) {
  if (overrides == null) {
    return { own: undefined, nested: undefined };
  }
  const own = overrides[id];
  let nested;
  const prefix = `${id}.`;
  for (const key of Object.keys(overrides)) {
    if (key.startsWith(prefix)) {
      (nested ??= {})[key.slice(prefix.length)] = overrides[key];
    }
  }
  return { own, nested };
}

/**
 * Filters a part's override args against its lock declaration, so locked args
 * can never take effect even if present in a persisted override (defense in
 * depth; consumers that build overrides should also refuse them upstream).
 *
 * @param {Object|undefined} overrideArgs - The part's own override args.
 * @param {true|ReadonlyArray<string>|null|undefined} lock - The part's lock declaration.
 * @returns {Object|undefined} The allowed override args, or undefined when none apply.
 */
export function applyLock(overrideArgs, lock) {
  if (overrideArgs == null) {
    return undefined;
  }
  if (lock === true) {
    // The whole part is locked: no in-place override applies.
    return undefined;
  }
  if (Array.isArray(lock) && lock.length > 0) {
    const allowed = {};
    for (const [key, value] of Object.entries(overrideArgs)) {
      if (!lock.includes(key)) {
        allowed[key] = value;
      }
    }
    return allowed;
  }
  return overrideArgs;
}

/**
 * Resolves the effective args for one part: the part's code-defined default
 * args merged with the (lock-filtered) instance override. The block's own
 * schema defaults are layered underneath later by the render pipeline, exactly
 * as they are for an ordinary entry's `args`.
 *
 * @param {{args?: Object|null, lock?: true|ReadonlyArray<string>|null}} part - The part definition.
 * @param {Object|undefined} ownOverride - The instance override for this part's own args.
 * @returns {Object} The effective args for the synthesized child entry.
 */
export function resolvePartArgs(part, ownOverride) {
  const base = part.args ?? {};
  const allowed = applyLock(ownOverride, part.lock);
  return allowed ? { ...base, ...allowed } : { ...base };
}

/**
 * Synthesizes the render-only child entries for a composite entry from its
 * block's `parts`. Each child carries the effective args (defaults ⊕
 * lock-filtered override), a deterministic stable key derived from the
 * composite instance + id path, the deeper overrides for its own descendants,
 * and markers correlating it back to the persisted composite and override path.
 *
 * Synthesis reads its position (composite instance key, accumulated id path,
 * overrides) from markers on the entry it is given, so a synthesized child that
 * is itself a composite re-synthesizes correctly on the next walk level with no
 * explicit recursion here — the ordinary child-walk drives the depth.
 *
 * The produced entries are never persisted; they exist only for the duration of
 * a render/prefetch walk.
 *
 * @param {Object} entry - The composite layout entry (persisted, or a synthesized parent part).
 * @param {{parts: ReadonlyArray<{id: string, block: string|Function, args?: Object|null, lock?: true|ReadonlyArray<string>|null}>}} metadata - The composite block's metadata.
 * @returns {Array<Object>} The synthesized child entries.
 */
export function synthesizePartEntries(entry, metadata) {
  const overrides = entry.overrides;
  // `__compositeKey` is set on synthesized children (the outermost composite's
  // own stable key); a real composite entry uses its own `__stableKey`.
  const compositeKey = entry.__compositeKey ?? String(entry.__stableKey);
  // The derived-key prefix for this level's children: the entry's own stable
  // key (numeric for a real composite, the derived string for a synthesized one).
  const keyPrefix = String(entry.__stableKey);
  const pathPrefix = entry.__partPath ?? "";

  return metadata.parts.map((part) => {
    const { own, nested } = childOverridesFor(overrides, part.id);
    const partPath = joinPartPath(pathPrefix, part.id);
    return {
      block: part.block,
      args: resolvePartArgs(part, own),
      // Deeper overrides flow to the next synthesis level via the child's own
      // `overrides`, so nesting needs no special handling beyond the walk.
      overrides: nested,
      // Always visible: parts don't carry conditions, so they skip the
      // condition pass that stamps `__visible` on persisted entries.
      __visible: true,
      __fromComposite: true,
      __partId: part.id,
      __partPath: partPath,
      __compositeKey: compositeKey,
      __partLock: part.lock ?? null,
      __stableKey: `${keyPrefix}${PART_KEY_SEGMENT}${part.id}`,
    };
  });
}
