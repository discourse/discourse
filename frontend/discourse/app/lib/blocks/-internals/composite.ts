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
 */

import type { BlockPart } from "discourse/blocks/types";

/**
 * A single part's override args: the values an instance supplies to replace the
 * part's code-defined defaults, keyed by arg name.
 */
type OverrideArgs = Record<string, unknown>;

/**
 * A composite entry's flat, path-keyed overrides. A key that is exactly a part
 * id addresses that part's own args; a dotted key (`action.label`) addresses a
 * descendant part deeper in the composition.
 */
type CompositeOverrides = Record<string, OverrideArgs>;

/**
 * The subset of a layout entry this module reads when synthesizing parts. A
 * persisted composite entry carries a numeric `__stableKey`; a synthesized part
 * (itself possibly a composite) carries the derived string markers instead.
 */
interface CompositeEntryInput {
  overrides?: CompositeOverrides | null;
  __stableKey?: number | string;
  __compositeKey?: string;
  __partPath?: string;
}

/**
 * A render-only child entry synthesized from a composite's part. Never
 * persisted — it exists only for the duration of a render/prefetch walk.
 */
interface SynthesizedPartEntry {
  block: BlockPart["block"];
  args: Record<string, unknown>;
  overrides?: CompositeOverrides;
  __visible: true;
  __fromComposite: true;
  __partId: string;
  __partPath: string;
  __compositeKey: string;
  __partLock: true | readonly string[] | null;
  __stableKey: string;
}

/**
 * Separator embedded in a synthesized part's stable key, between the composite
 * instance's key and a part id. Repeats for each nesting level, e.g.
 * `42::part::action::part::label`.
 */
export const PART_KEY_SEGMENT = "::part::";

/**
 * Joins id-path segments into a dot-delimited override-path key
 * (e.g. `["action", "label"]` → `"action.label"`). Empty/nullish segments are
 * dropped, so `joinPartPath("", "title")` is `"title"`.
 *
 * @param segments - The id-path segments to join.
 * @returns The dot-delimited override-path key.
 */
export function joinPartPath(
  ...segments: (string | null | undefined)[]
): string {
  return segments.filter((s) => s != null && s !== "").join(".");
}

/**
 * Splits a dot-delimited override path into its id segments. An empty/nullish
 * path yields an empty array.
 *
 * @param path - The dot-delimited override path.
 * @returns The id segments.
 */
export function splitPartPath(path: string | null | undefined): string[] {
  return path ? path.split(".") : [];
}

/**
 * Returns true when a stable key belongs to a synthesized part (i.e. it
 * encodes a composite instance and an id path).
 *
 * @param stableKey - The stable key to test.
 * @returns Whether the key encodes a synthesized part.
 */
export function isPartKey(stableKey: unknown): boolean {
  return typeof stableKey === "string" && stableKey.includes(PART_KEY_SEGMENT);
}

/**
 * Parses a synthesized part's stable key into the owning composite instance's
 * key and the id path beneath it.
 *
 * For `"42::part::action::part::label"` the composite key is `"42"` and the id
 * path is `["action", "label"]`. The `compositeKey` is the persisted composite
 * entry's own
 * `__stableKey` (a number, returned here as its string form); the id path
 * addresses the part beneath it and matches the persisted override key
 * (`action.label`).
 *
 * @param stableKey - The synthesized part's stable key.
 * @returns The owning composite key and id path, or `null` when the key does
 *   not encode a synthesized part.
 */
export function parsePartKey(
  stableKey: string
): { compositeKey: string; idPath: string[] } | null {
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
 * @param overrides - The composite's path-keyed overrides.
 * @param id - The part id.
 * @returns The part's own override args and the deeper overrides for its
 *   descendants.
 */
export function childOverridesFor(
  overrides: CompositeOverrides | null | undefined,
  id: string
): { own: OverrideArgs | undefined; nested: CompositeOverrides | undefined } {
  if (overrides == null) {
    return { own: undefined, nested: undefined };
  }
  const own = overrides[id];
  let nested: CompositeOverrides | undefined;
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
 * @param overrideArgs - The part's own override args.
 * @param lock - The part's lock declaration.
 * @returns The allowed override args, or `undefined` when none apply.
 */
export function applyLock(
  overrideArgs: OverrideArgs | undefined,
  lock: true | readonly string[] | null | undefined
): OverrideArgs | undefined {
  if (overrideArgs == null) {
    return undefined;
  }
  if (lock === true) {
    // The whole part is locked: no in-place override applies.
    return undefined;
  }
  if (Array.isArray(lock) && lock.length > 0) {
    const allowed: OverrideArgs = {};
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
 * @param part - The part definition.
 * @param ownOverride - The instance override for this part's own args.
 * @returns The effective args for the synthesized child entry.
 */
export function resolvePartArgs(
  part: {
    args?: Readonly<Record<string, unknown>> | null;
    lock?: true | readonly string[] | null;
  },
  ownOverride: OverrideArgs | undefined
): Record<string, unknown> {
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
 * @param entry - The composite layout entry (persisted, or a synthesized parent
 *   part).
 * @param metadata - The composite block's metadata, carrying its `parts`.
 * @returns The synthesized child entries.
 */
export function synthesizePartEntries(
  entry: CompositeEntryInput,
  metadata: { parts: readonly BlockPart[] }
): SynthesizedPartEntry[] {
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
