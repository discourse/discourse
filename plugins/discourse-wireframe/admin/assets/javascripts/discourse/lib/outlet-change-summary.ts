import type { LayoutEntry } from "discourse/blocks/types";
import {
  isLayoutBlockEntry,
  serializeEntryForSave,
  type ValidatedLayoutEntry,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";

/** One block's change, for listing what an edit touched. */
export type BlockChange = {
  /** The entry as it is now, or as it was for a removed block. */
  entry: LayoutEntry;
  /** What happened to the block. */
  kind: "added" | "removed" | "moved" | "edited";
};

/** Counts describing how an edited outlet differs from its baseline. */
export type ChangeSummary = {
  /** Each changed block, in layout order. */
  changes: BlockChange[];
  /** Blocks present only in the edited layout. */
  added: number;
  /** Blocks present only in the baseline layout. */
  removed: number;
  /** Blocks whose parent or sibling index changed. */
  moved: number;
  /** Blocks whose own persisted properties changed. */
  edited: number;
  /** Whether shared stable identity made the detailed counts trustworthy. */
  reliable: boolean;
};

type IndexedEntry = {
  /** Entry associated with the stable identity. */
  entry: LayoutEntry;
  /** Stable identity of the parent entry, or `null` at the root. */
  parentKey: string | number | null | undefined;
  /** Zero-based position among direct siblings. */
  index: number;
};

type EntryIndex = Map<string | number, IndexedEntry>;

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
 * @param before - Baseline resolved layout currently live.
 * @param after - Edited resolved layout from the session draft.
 * @returns Structural change counts for the outlet.
 */
export function diffLayouts(
  before: ValidatedLayoutEntry[] | null,
  after: ValidatedLayoutEntry[] | null
): ChangeSummary {
  const baseline = indexEntries(before, null, new Map());
  const edited = indexEntries(unwrapNewRoot(before, after), null, new Map());

  // No shared identity between two non-empty layouts means the keys desynced —
  // matching would report every block as both removed and re-added, which is
  // worse than useless. Fall back to a single "edited" signal.
  if (baseline.size > 0 && edited.size > 0 && !sharesAnyKey(baseline, edited)) {
    return {
      changes: [...edited.values()].map(({ entry }) => ({
        entry,
        kind: "edited" as const,
      })),
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
  const changes: BlockChange[] = [];

  for (const [key, info] of edited) {
    const prev = baseline.get(key);
    if (!prev) {
      added++;
      changes.push({ entry: info.entry, kind: "added" });
      continue;
    }
    // A block can be both moved and edited; the two metrics are independent and
    // both worth surfacing, so we count each on its own.
    if (prev.parentKey !== info.parentKey || prev.index !== info.index) {
      moved++;
      changes.push({ entry: info.entry, kind: "moved" });
    }
    if (ownPropsFingerprint(prev.entry) !== ownPropsFingerprint(info.entry)) {
      editedCount++;
      changes.push({ entry: info.entry, kind: "edited" });
    }
  }

  for (const [key, info] of baseline) {
    if (!edited.has(key)) {
      removed++;
      changes.push({ entry: info.entry, kind: "removed" });
    }
  }

  return {
    changes,
    added,
    removed,
    moved,
    edited: editedCount,
    reliable: true,
  };
}

/**
 * The editor wraps a layout in an implicit root layout so it can be edited. That
 * wrapper isn't something the author added, so it is left out of the comparison
 * and its children are compared with the baseline directly.
 *
 * @param before - Baseline resolved layout.
 * @param after - Edited resolved layout.
 * @returns The edited entries, without a wrapper that only exists in the editor.
 */
function unwrapNewRoot(
  before: ValidatedLayoutEntry[] | null,
  after: ValidatedLayoutEntry[] | null
): ValidatedLayoutEntry[] | null {
  const [root] = after ?? [];
  if (after?.length !== 1 || !root || !isLayoutBlockEntry(root)) {
    return after;
  }
  const known = indexEntries(before, null, new Map());
  return root.__stableKey != null && known.has(root.__stableKey)
    ? after
    : (root.children ?? []);
}

/**
 * Recursively indexes a layout's entries by `__stableKey`, recording each
 * block's parent key and sibling index so the diff can detect moves.
 *
 * @param entries - Entries at the current tree level.
 * @param parentKey - Stable identity of their parent.
 * @param map - Accumulated entry index.
 * @returns The populated entry index.
 */
function indexEntries(
  entries: ValidatedLayoutEntry[] | null,
  parentKey: string | number | null | undefined,
  map: EntryIndex
): EntryIndex {
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
 * @param a - First stable-identity index.
 * @param b - Second stable-identity index.
 * @returns Whether the indexes share at least one identity.
 */
function sharesAnyKey(a: EntryIndex, b: EntryIndex): boolean {
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
 * @param entry - Entry whose persisted properties should be fingerprinted.
 * @returns Stable JSON fingerprint excluding identity and children.
 */
function ownPropsFingerprint(entry: LayoutEntry): string {
  const serialized = serializeEntryForSave(entry);
  delete serialized.children;
  delete serialized.id;
  return JSON.stringify(serialized);
}
