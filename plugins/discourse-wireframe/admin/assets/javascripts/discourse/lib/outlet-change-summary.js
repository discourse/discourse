// @ts-check
import { serializeEntryForSave } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";

/**
 * Computes a structural change summary between two resolved layouts for the same
 * outlet — the baseline (what is live now, resolved with `ignoreSessionDraft`)
 * and the edited layout (the in-session draft on top). The result drives the
 * editor's change view ("+3 · ~2 · ↕1").
 *
 * Blocks are matched by `__stableKey`, the per-entry identity assigned in the
 * core block-outlet resolver. That key is preserved when the editor clones the
 * baseline into a draft, so a block left untouched keeps the same key on both
 * sides; a block added in-session gets a fresh key, and a removed one keeps its
 * key only on the baseline side. Matching on the key (rather than the persisted
 * `id`, which is author-optional and usually absent) is what lets us tell an
 * add/remove apart from a move or an in-place edit.
 *
 * @typedef {Object} ChangeSummary
 * @property {number} added - Blocks present only in the edited layout.
 * @property {number} removed - Blocks present only in the baseline.
 * @property {number} moved - Blocks whose parent or sibling index changed.
 * @property {number} edited - Blocks whose own props (args, classes, conditions,
 *   container args, overrides) changed in place.
 * @property {boolean} reliable - False when the two layouts share no block
 *   identity at all (an identity desync that should not happen in-session); the
 *   caller should then show a generic "edited" indicator rather than the counts.
 */

/**
 * @param {Array<Object>|null} before - The baseline resolved layout (live).
 * @param {Array<Object>|null} after - The edited resolved layout (session draft).
 * @returns {ChangeSummary}
 */
export function diffLayouts(before, after) {
  const baseline = indexEntries(before, null, new Map());
  const edited = indexEntries(after, null, new Map());

  // No shared identity between two non-empty layouts means the keys desynced —
  // matching would report every block as both removed and re-added, which is
  // worse than useless. Fall back to a single "edited" signal.
  if (baseline.size > 0 && edited.size > 0 && !sharesAnyKey(baseline, edited)) {
    return {
      added: 0,
      removed: 0,
      moved: 0,
      edited: edited.size,
      reliable: false,
    };
  }

  let added = 0;
  let removed = 0;
  let moved = 0;
  let editedCount = 0;

  for (const [key, info] of edited) {
    const prev = baseline.get(key);
    if (!prev) {
      added++;
      continue;
    }
    // A block can be both moved and edited; the two metrics are independent and
    // both worth surfacing, so we count each on its own.
    if (prev.parentKey !== info.parentKey || prev.index !== info.index) {
      moved++;
    }
    if (ownPropsFingerprint(prev.entry) !== ownPropsFingerprint(info.entry)) {
      editedCount++;
    }
  }

  for (const key of baseline.keys()) {
    if (!edited.has(key)) {
      removed++;
    }
  }

  return { added, removed, moved, edited: editedCount, reliable: true };
}

/**
 * Recursively indexes a layout's entries by `__stableKey`, recording each
 * block's parent key and sibling index so the diff can detect moves.
 *
 * @param {Array<Object>|null} entries - The entries at this level.
 * @param {(number|string|null)} parentKey - The parent block's `__stableKey`.
 * @param {Map<(number|string), {entry: Object, parentKey: (number|string|null), index: number}>} map - Accumulator.
 * @returns {Map<(number|string), {entry: Object, parentKey: (number|string|null), index: number}>}
 */
function indexEntries(entries, parentKey, map) {
  (entries ?? []).forEach((entry, index) => {
    const key = entry.__stableKey;
    if (key != null) {
      map.set(key, { entry, parentKey, index });
    }
    if (entry.children?.length) {
      indexEntries(entry.children, key, map);
    }
  });
  return map;
}

/**
 * Whether the two indexes share at least one block identity.
 *
 * @param {Map<(number|string), Object>} a
 * @param {Map<(number|string), Object>} b
 * @returns {boolean}
 */
function sharesAnyKey(a, b) {
  for (const key of a.keys()) {
    if (b.has(key)) {
      return true;
    }
  }
  return false;
}

/**
 * A stable fingerprint of an entry's own content, excluding its identity and its
 * children (structural child changes are counted separately by the walk). Reuses
 * the canonical save serializer so the comparison matches what would persist, then
 * drops `children` and the author `id` so neither nesting nor an id tweak reads as
 * a content edit.
 *
 * @param {Object} entry
 * @returns {string}
 */
function ownPropsFingerprint(entry) {
  const serialized = serializeEntryForSave(entry);
  delete serialized.children;
  delete serialized.id;
  return JSON.stringify(serialized);
}
