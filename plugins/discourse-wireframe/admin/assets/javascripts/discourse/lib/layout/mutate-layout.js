// @ts-check
/**
 * Layout-mutation helpers for the wireframe.
 *
 * The editor publishes its in-progress edits as a `session-draft` layer via
 * `api.setLayoutLayer`. The draft layout is a deep clone of the resolved
 * layout (preserving `__stableKey` so DOM identity carries over), wrapped at
 * publish time so each draft entry's `args` lands in its own `trackedObject`.
 * Subsequent edits mutate those draft args in place — the trackedObject's
 * compute-ref proxy propagates the change to the rendered block without
 * re-publishing the layer.
 *
 * Structural mutations (drag-drop, palette additions) use the immutable
 * `replaceEntryArgs` family to build new layouts and republish via
 * `setLayoutLayer`.
 *
 * These helpers are pure logic — no Glimmer, no service injection — so the
 * editor service stays small and the helpers stay testable in isolation.
 */
import {
  applyLock,
  splitPartPath,
  synthesizePartEntries,
} from "discourse/lib/blocks/-internals/composite";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { tryResolveBlock } from "discourse/lib/blocks/-internals/registry/block";
import { collectEntryFailures } from "discourse/lib/blocks/-internals/validation/layout";
// `entryKey` lives in its own file in the UNIVERSAL bundle so the
// live-page `grid-math.js` can use it without dragging mutate-layout
// (admin-only) into the universal bundle. This file is admin-only; we
// import via the absolute addon path because the universal entry-key
// module isn't reachable via a relative path from this admin location.
// Re-exported so existing call sites that import it from
// `lib/mutate-layout` keep working.
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/entry-key";
import { friendlyErrorMessage } from "discourse/plugins/discourse-wireframe/discourse/lib/friendly-error-message";

export { entryKey };

/**
 * Walks a layout looking for the entry whose composite key matches.
 *
 * @param {Array<Object>} layout
 * @param {string} key
 * @returns {Object|null}
 */
export function findEntry(layout, key) {
  if (!layout) {
    return null;
  }
  for (const entry of layout) {
    if (entryKey(entry) === key) {
      return entry;
    }
    if (entry.children?.length) {
      const found = findEntry(entry.children, key);
      if (found) {
        return found;
      }
    }
  }
  return null;
}

/**
 * Walks a layout looking for the entry whose `__stableKey` matches (compared
 * as a string). Used to resolve a composite from the stable-key prefix encoded
 * in a synthesized part's key, where the part itself has no persisted entry.
 *
 * @param {Array<Object>} layout
 * @param {string} stableKey - The composite entry's stable key, as a string.
 * @returns {Object|null}
 */
export function findEntryByStableKey(layout, stableKey) {
  if (!layout) {
    return null;
  }
  for (const entry of layout) {
    if (String(entry.__stableKey) === stableKey) {
      return entry;
    }
    if (entry.children?.length) {
      const found = findEntryByStableKey(entry.children, stableKey);
      if (found) {
        return found;
      }
    }
  }
  return null;
}

/**
 * Returns a new layout where the entry matching `key` has its `args`
 * replaced by the result of `updater(currentArgs)`. All other entries are
 * carried through with the same identity (their `__stableKey` and any other
 * properties are preserved by reference).
 *
 * The targeted entry is always cloned even when `updater` returns the same
 * args reference — the cloned entry gets a fresh `args` object so the
 * leaf-block render cache sees a new reference and re-curries.
 *
 * @param {Array<Object>} layout
 * @param {string} key
 * @param {(currentArgs: Object) => Object} updater
 * @returns {{layout: Array<Object>, changed: boolean}}
 */
export function replaceEntryArgs(layout, key, updater) {
  let changed = false;

  function walk(entries) {
    let subtreeChanged = false;
    const result = entries.map((entry) => {
      if (entryKey(entry) === key) {
        changed = true;
        subtreeChanged = true;
        const currentArgs = entry.args ?? {};
        return cloneEntryShell(entry, { args: { ...updater(currentArgs) } });
      }
      if (entry.children?.length) {
        const newChildren = walk(entry.children);
        if (newChildren !== entry.children) {
          subtreeChanged = true;
          return cloneEntryShell(entry, { children: newChildren });
        }
      }
      return entry;
    });
    // Preserve the input array's identity when nothing in this subtree
    // changed; downstream (`{ ...entry, children }`) compares by reference to
    // decide whether to clone the parent. This keeps untouched ancestors
    // identity-stable across mutations.
    return subtreeChanged ? result : entries;
  }

  const newLayout = walk(layout);
  return { layout: newLayout, changed };
}

/**
 * Returns a new layout where the entry matching `key` has its
 * `containerArgs[namespace]` bag replaced by the result of
 * `updater(currentBag)`. The placement bag (e.g. `containerArgs.grid`) is
 * replaced wholesale so the `containerArgs` trackedObject's per-key tag
 * dirties — that's what triggers the parent container's render to re-read
 * the bag. In-place mutation of a nested property (`bag.column = "3"`)
 * would NOT propagate, since the inner bag is a plain object.
 *
 * Mirrors `replaceEntryArgs`: ancestor identity is preserved when nothing
 * in the subtree changed.
 *
 * @param {Array<Object>} layout
 * @param {string} key
 * @param {string} namespace - The childArgs namespace key (e.g. "grid").
 * @param {(currentBag: Object) => Object} updater
 * @returns {{layout: Array<Object>, changed: boolean}}
 */
export function replaceEntryContainerArgs(layout, key, namespace, updater) {
  let changed = false;

  function walk(entries) {
    let subtreeChanged = false;
    const result = entries.map((entry) => {
      if (entryKey(entry) === key) {
        changed = true;
        subtreeChanged = true;
        const currentContainerArgs = entry.containerArgs ?? {};
        const currentBag = currentContainerArgs[namespace] ?? {};
        return cloneEntryShell(entry, {
          containerArgs: {
            ...currentContainerArgs,
            [namespace]: { ...updater(currentBag) },
          },
        });
      }
      if (entry.children?.length) {
        const newChildren = walk(entry.children);
        if (newChildren !== entry.children) {
          subtreeChanged = true;
          return cloneEntryShell(entry, { children: newChildren });
        }
      }
      return entry;
    });
    return subtreeChanged ? result : entries;
  }

  const newLayout = walk(layout);
  return { layout: newLayout, changed };
}

/**
 * Replaces the entry matching `key` with a wholly new entry object.
 * Used by the inspector's Raw JSON tab, which lets the author edit
 * the entry's serialised form and commit the parsed result.
 *
 * Preserves the matched entry's `__stableKey` so the rendered block
 * keeps its DOM identity across the swap — author edits shouldn't
 * remount the block.
 *
 * @param {Array<Object>} layout
 * @param {string} key
 * @param {Object} newEntry
 * @returns {{layout: Array<Object>, changed: boolean, entry: Object|null}}
 *   `entry` is the clone actually placed into the layout (with the replaced
 *   entry's `__stableKey`), or `null` when nothing matched.
 */
export function replaceEntryInPlace(layout, key, newEntry) {
  let changed = false;
  // The clone actually inserted into the new layout. `newEntry` is cloned
  // (inheriting the replaced entry's stable key), so callers that need to
  // act on the placed entry — e.g. auto-selecting it — must use this, not
  // the original `newEntry` (which never receives a stable key).
  let inserted = null;

  function walk(entries) {
    let subtreeChanged = false;
    const result = entries.map((entry) => {
      if (entryKey(entry) === key) {
        changed = true;
        subtreeChanged = true;
        inserted = cloneEntryShell(newEntry, {
          __stableKey: entry.__stableKey,
        });
        return inserted;
      }
      if (entry.children?.length) {
        const newChildren = walk(entry.children);
        if (newChildren !== entry.children) {
          subtreeChanged = true;
          return cloneEntryShell(entry, { children: newChildren });
        }
      }
      return entry;
    });
    return subtreeChanged ? result : entries;
  }

  const newLayout = walk(layout);
  return { layout: newLayout, changed, entry: inserted };
}

/**
 * Returns the ancestor chain from the layout root down to (and
 * including) the entry matching `key`. Each element is the matching
 * entry object itself — not a wrapper. `null` is returned when no
 * entry matches.
 *
 * Used by the editor's breadcrumb component to render the ancestry
 * of the selected block.
 *
 * @param {Array<Object>} layout
 * @param {string} key
 * @returns {Array<Object>|null}
 */
export function findAncestryPath(layout, key) {
  function walk(entries, trail) {
    for (const entry of entries) {
      const here = [...trail, entry];
      if (entryKey(entry) === key) {
        return here;
      }
      if (entry.children?.length) {
        const found = walk(entry.children, here);
        if (found) {
          return found;
        }
      }
    }
    return null;
  }
  return walk(layout, []);
}

/**
 * Locates the matched entry's siblings (i.e. the children array of its
 * direct parent) and the entry's index within that array. Used by the
 * editor's "move up / move down" affordances and any future
 * sibling-relative mutation.
 *
 * Returns `null` when no matching entry exists.
 *
 * @param {Array<Object>} layout
 * @param {string} key
 * @returns {{siblings: Array<Object>, index: number}|null}
 */
export function findEntrySiblings(layout, key) {
  function walk(entries) {
    const index = entries.findIndex((entry) => entryKey(entry) === key);
    if (index !== -1) {
      return { siblings: entries, index };
    }
    for (const entry of entries) {
      if (entry.children?.length) {
        const found = walk(entry.children);
        if (found) {
          return found;
        }
      }
    }
    return null;
  }
  return walk(layout);
}

/**
 * Returns a new layout where the entry matching `key` has its `id`
 * replaced. `id` is the entry-level identifier used for CSS targeting
 * (BEM modifier classes, `data-block-id` attribute). Authors edit it
 * from the inspector's metadata section.
 *
 * Pass `null` or an empty string to clear the property — the entry is
 * spread without `id` so the serialised output drops it cleanly. The
 * caller is responsible for format validation against
 * `VALID_BLOCK_ID_PATTERN`; this helper accepts any string.
 *
 * @param {Array<Object>} layout
 * @param {string} key
 * @param {string|null} nextId
 * @returns {{layout: Array<Object>, changed: boolean}}
 */
export function replaceEntryId(layout, key, nextId) {
  let changed = false;

  function walk(entries) {
    let subtreeChanged = false;
    const result = entries.map((entry) => {
      if (entryKey(entry) === key) {
        changed = true;
        subtreeChanged = true;
        if (nextId == null || nextId === "") {
          // eslint-disable-next-line no-unused-vars
          const { id, ...rest } = entry;
          clearValidatorStamps(rest);
          return rest;
        }
        return cloneEntryShell(entry, { id: nextId });
      }
      if (entry.children?.length) {
        const newChildren = walk(entry.children);
        if (newChildren !== entry.children) {
          subtreeChanged = true;
          return cloneEntryShell(entry, { children: newChildren });
        }
      }
      return entry;
    });
    return subtreeChanged ? result : entries;
  }

  const newLayout = walk(layout);
  return { layout: newLayout, changed };
}

/**
 * Replaces the `conditions` field on a matched entry. Mirrors
 * `replaceEntryArgs` but targets the entry's condition tree (the
 * visibility predicate) rather than the rendered args.
 *
 * Accepts `null` to clear the conditions entirely. Untouched subtrees
 * keep their array identity so downstream consumers (block-outlet
 * reactivity) can short-circuit re-renders.
 *
 * @param {Array<Object>} layout
 * @param {string} key
 * @param {Array|Object|null} newConditions
 * @returns {{layout: Array<Object>, changed: boolean}}
 */
export function replaceEntryConditions(layout, key, newConditions) {
  let changed = false;

  function walk(entries) {
    let subtreeChanged = false;
    const result = entries.map((entry) => {
      if (entryKey(entry) === key) {
        changed = true;
        subtreeChanged = true;
        // Drop the `conditions` field entirely when clearing; persist
        // serialisation downstream skips falsy conditions anyway, but
        // omitting them keeps the in-memory shape tidy.
        if (newConditions == null) {
          // eslint-disable-next-line no-unused-vars
          const { conditions, ...rest } = entry;
          clearValidatorStamps(rest);
          return rest;
        }
        return cloneEntryShell(entry, { conditions: newConditions });
      }
      if (entry.children?.length) {
        const newChildren = walk(entry.children);
        if (newChildren !== entry.children) {
          subtreeChanged = true;
          return cloneEntryShell(entry, { children: newChildren });
        }
      }
      return entry;
    });
    return subtreeChanged ? result : entries;
  }

  const newLayout = walk(layout);
  return { layout: newLayout, changed };
}

/**
 * Convenience wrapper that immutably sets a single arg on the matched entry.
 *
 * @param {Array<Object>} layout
 * @param {string} key
 * @param {string} argName
 * @param {*} value
 * @returns {{layout: Array<Object>, changed: boolean}}
 */
export function setEntryArg(layout, key, argName, value) {
  return replaceEntryArgs(layout, key, (current) => ({
    ...current,
    [argName]: value,
  }));
}

/**
 * Returns a new layout with the entry matching `key` removed. Preserves the
 * identity of untouched siblings and ancestor subtrees by returning the input
 * arrays/entries by reference when nothing in their subtree changed — same
 * idiom as `replaceEntryArgs`. The removed entry is returned alongside the
 * mutated layout so callers (e.g. `moveEntry`) can re-insert it elsewhere.
 *
 * @param {Array<Object>} layout
 * @param {string} key
 * @returns {{layout: Array<Object>, removed: Object|null, changed: boolean}}
 */
export function removeEntry(layout, key) {
  let removed = null;

  function walk(entries) {
    let subtreeChanged = false;
    const result = [];
    for (const entry of entries) {
      if (entryKey(entry) === key) {
        removed = entry;
        subtreeChanged = true;
        continue;
      }
      if (entry.children?.length) {
        const newChildren = walk(entry.children);
        if (newChildren !== entry.children) {
          subtreeChanged = true;
          result.push(cloneEntryShell(entry, { children: newChildren }));
          continue;
        }
      }
      result.push(entry);
    }
    return subtreeChanged ? result : entries;
  }

  const newLayout = walk(layout);
  return { layout: newLayout, removed, changed: removed != null };
}

/**
 * Returns a new layout where `entry` has been spliced into `layout` adjacent
 * to the entry whose key matches `targetKey`. `position` controls placement
 * relative to the target:
 *
 *   - `"before"` — sibling immediately preceding the target;
 *   - `"after"`  — sibling immediately following the target;
 *   - `"inside"` — first child of the target (target must be a container with
 *     a `children` array — created if absent).
 *
 * If `targetKey` is null, `entry` is appended to the root of `layout`. As with
 * `replaceEntryArgs` and `removeEntry`, untouched subtrees are returned by
 * reference so DOM identity is preserved in the rendered tree.
 *
 * @param {Array<Object>} layout
 * @param {string|null} targetKey
 * @param {Object} entry
 * @param {"before"|"after"|"inside"} position
 * @returns {{layout: Array<Object>, changed: boolean}}
 */
export function insertEntryAt(layout, targetKey, entry, position) {
  if (targetKey == null) {
    return { layout: [...layout, entry], changed: true };
  }

  let inserted = false;

  function walk(entries) {
    let subtreeChanged = false;
    const result = [];
    for (const candidate of entries) {
      if (!inserted && entryKey(candidate) === targetKey) {
        inserted = true;
        if (position === "before") {
          result.push(entry, candidate);
          subtreeChanged = true;
          continue;
        }
        if (position === "after") {
          result.push(candidate, entry);
          subtreeChanged = true;
          continue;
        }
        if (position === "inside") {
          // Spread existing children into a new array so we don't mutate the
          // input. When the container has no children, start a fresh array.
          const nextChildren = candidate.children
            ? [entry, ...candidate.children]
            : [entry];
          result.push(cloneEntryShell(candidate, { children: nextChildren }));
          subtreeChanged = true;
          continue;
        }
        if (position === "inside-end") {
          // Like "inside" but APPENDS, so an "add to the end" gesture (a tab
          // strip's trailing affordance) lands the new child last rather than
          // first.
          const nextChildren = candidate.children
            ? [...candidate.children, entry]
            : [entry];
          result.push(cloneEntryShell(candidate, { children: nextChildren }));
          subtreeChanged = true;
          continue;
        }
      }
      if (!inserted && candidate.children?.length) {
        const newChildren = walk(candidate.children);
        if (newChildren !== candidate.children) {
          subtreeChanged = true;
          result.push(cloneEntryShell(candidate, { children: newChildren }));
          continue;
        }
      }
      result.push(candidate);
    }
    return subtreeChanged ? result : entries;
  }

  const newLayout = walk(layout);
  return { layout: newLayout, changed: inserted };
}

/**
 * Removes the entry matching `sourceKey` and re-inserts it adjacent to
 * `targetKey` in a single immutable step. Returns the resulting layout and
 * a `changed` flag — `false` when either the source wasn't found or the
 * target wasn't found (in which case `layout` comes back unchanged).
 *
 * Self-targeting moves (sourceKey === targetKey) are a no-op. Moving a
 * container into one of its own descendants is also rejected as a no-op.
 *
 * @param {Array<Object>} layout
 * @param {string} sourceKey
 * @param {string} targetKey
 * @param {"before"|"after"|"inside"} position
 * @returns {{layout: Array<Object>, changed: boolean}}
 */
export function moveEntry(layout, sourceKey, targetKey, position) {
  if (sourceKey === targetKey) {
    return { layout, changed: false };
  }

  // Reject moves that would re-parent a container into one of its own
  // descendants — that produces a cycle and breaks rendering.
  const sourceEntry = findEntry(layout, sourceKey);
  if (sourceEntry && containsKey(sourceEntry, targetKey)) {
    return { layout, changed: false };
  }

  const removal = removeEntry(layout, sourceKey);
  if (!removal.changed || !removal.removed) {
    return { layout, changed: false };
  }
  const insertion = insertEntryAt(
    removal.layout,
    targetKey,
    removal.removed,
    position
  );
  if (!insertion.changed) {
    return { layout, changed: false };
  }
  return { layout: insertion.layout, changed: true };
}

/**
 * Returns true when `entry`'s subtree (children, grandchildren, ...) contains
 * an entry whose composite key matches `key`. Used by `moveEntry` to bail on
 * self-nesting moves.
 *
 * @param {Object} entry
 * @param {string} key
 * @returns {boolean}
 */
function containsKey(entry, key) {
  if (!entry?.children?.length) {
    return false;
  }
  for (const child of entry.children) {
    if (entryKey(child) === key) {
      return true;
    }
    if (containsKey(child, key)) {
      return true;
    }
  }
  return false;
}

/**
 * Resolves the part definition addressed by an id path beneath a composite
 * entry, walking the parts metadata level by level (resolving each nested
 * composite's block). Returns the leaf part definition (with its `block`,
 * default `args`, and `lock`), or null if the path doesn't resolve.
 *
 * @param {Object} entry - The composite layout entry.
 * @param {string[]} idPath - The part-id path (e.g. ["actions", "primary"]).
 * @returns {{id: string, block: string|Function, args: Object|null, lock: true|string[]|null}|null}
 */
export function resolvePartDef(entry, idPath) {
  let block = entry?.block;
  let part = null;
  for (const id of idPath) {
    const resolved = block ? tryResolveBlock(block) : null;
    const meta = resolved ? getBlockMetadata(resolved) : null;
    part = meta?.parts?.find((p) => p.id === id) ?? null;
    if (!part) {
      return null;
    }
    block = part.block;
  }
  return part;
}

/**
 * Returns a new layout where the composite entry matching `compositeKey` has
 * the override for one part path replaced by `updater(currentOverrideArgs)`.
 * The override is keyed by the dot-delimited `partPath` and holds that inner
 * block's own args. Locked args are dropped defensively (the edit surface
 * should already refuse them). An update that resolves to an empty object
 * removes the override key entirely (back to the part's code default).
 *
 * Mirrors `replaceEntryArgs`: untouched ancestors keep their identity.
 *
 * @param {Array<Object>} layout
 * @param {string} compositeKey - The composite entry's key.
 * @param {string} partPath - Dot-delimited part-id path (e.g. "actions.primary").
 * @param {(currentArgs: Object) => Object} updater
 * @returns {{layout: Array<Object>, changed: boolean}}
 */
export function setPartOverride(layout, compositeKey, partPath, updater) {
  let changed = false;

  function walk(entries) {
    let subtreeChanged = false;
    const result = entries.map((entry) => {
      if (entryKey(entry) === compositeKey) {
        changed = true;
        subtreeChanged = true;
        const current = entry.overrides?.[partPath] ?? {};
        const updated = stripNullish({ ...updater({ ...current }) });
        const partDef = resolvePartDef(entry, splitPartPath(partPath));
        const allowed = applyLock(updated, partDef?.lock) ?? {};
        const overrides = { ...(entry.overrides ?? {}) };
        if (Object.keys(allowed).length > 0) {
          overrides[partPath] = allowed;
        } else {
          delete overrides[partPath];
        }
        return cloneEntryShell(entry, { overrides });
      }
      if (entry.children?.length) {
        const newChildren = walk(entry.children);
        if (newChildren !== entry.children) {
          subtreeChanged = true;
          return cloneEntryShell(entry, { children: newChildren });
        }
      }
      return entry;
    });
    return subtreeChanged ? result : entries;
  }

  const newLayout = walk(layout);
  return { layout: newLayout, changed };
}

/**
 * Returns a new layout where the composite entry matching `compositeKey` is
 * detached: its code-defined parts are materialised into explicit `children`
 * (resolved args ⊕ overrides) and its `overrides` map is dropped, so it
 * thereafter renders as a plain container the author can freely restructure.
 *
 * Detach peels exactly ONE layer: a child that is itself a composite keeps its
 * remaining (deeper) overrides, so it stays composed and can be detached in
 * turn. The wrapper entry keeps its `__stableKey`; the new children get fresh
 * keys minted at publish time.
 *
 * No-op when the entry is not a composite or already has explicit children.
 *
 * @param {Array<Object>} layout
 * @param {string} compositeKey
 * @returns {{layout: Array<Object>, changed: boolean}}
 */
export function detachComposite(layout, compositeKey) {
  let changed = false;

  function walk(entries) {
    let subtreeChanged = false;
    const result = entries.map((entry) => {
      if (entryKey(entry) === compositeKey) {
        const resolved = entry.block ? tryResolveBlock(entry.block) : null;
        const meta = resolved ? getBlockMetadata(resolved) : null;
        if (!meta?.parts || entry.children?.length) {
          // Not a composable composite, or already detached — leave as-is.
          return entry;
        }
        changed = true;
        subtreeChanged = true;
        const children = synthesizePartEntries(entry, meta).map(
          detachedChildFromSynthesized
        );
        const next = cloneEntryShell(entry, { children });
        // Detached: the composition no longer drives this entry.
        delete next.overrides;
        return next;
      }
      if (entry.children?.length) {
        const newChildren = walk(entry.children);
        if (newChildren !== entry.children) {
          subtreeChanged = true;
          return cloneEntryShell(entry, { children: newChildren });
        }
      }
      return entry;
    });
    return subtreeChanged ? result : entries;
  }

  const newLayout = walk(layout);
  return { layout: newLayout, changed };
}

/**
 * Turns one synthesized part entry into a real, persistable child entry:
 * keeps the block, the resolved args, and any deeper overrides (so a composite
 * child stays composed — detach peels one layer), and drops the synthetic
 * markers and derived key so a fresh `__stableKey` mints at publish.
 *
 * @param {Object} synthesized - A `synthesizePartEntries` result.
 * @returns {Object}
 */
function detachedChildFromSynthesized(synthesized) {
  const child = { block: synthesized.block, args: { ...synthesized.args } };
  if (synthesized.overrides && Object.keys(synthesized.overrides).length > 0) {
    child.overrides = cloneOverrides(synthesized.overrides);
  }
  return child;
}

/**
 * Returns a structural deep clone of a layout suitable for publishing as a
 * `session-draft` layer. The clone preserves each entry's `__stableKey` and
 * passes through immutable references (block class, conditions, id) by
 * reference. Each entry's `args` is copied into a fresh POJO so that
 * `assignStableKeys` (run by `_setLayoutLayer`) wraps those POJOs in their
 * own `trackedObject` proxies — keeping draft mutations isolated from the
 * underlying layer's args. `containerArgs` is deep-cloned too (one level
 * for each namespace bag) for the same reason: the inspector mutates
 * placement on the draft entry and that must not leak back into the
 * theme / code-default layer.
 *
 * @param {Array<Object>} layout
 * @returns {Array<Object>}
 */
export function cloneLayoutForDraft(layout) {
  return layout.map(cloneEntryForDraft);
}

function cloneEntryForDraft(entry) {
  const clone = { ...entry };
  // Drop validation-stamping side fields the source layer's validator
  // may have set. They describe the source layer's state, not the
  // draft's — keeping them would surface stale error chrome on entries
  // whose data we then sanitise via `stripNullish` below.
  clearValidatorStamps(clone);
  // Always materialise `args` on the draft, even when the source entry had
  // no args object (e.g. `serializeEntryForSave` omits it when every key is
  // empty, so a reloaded layout brings back `{ block }` only). The editor's
  // live-edit write path (`inlineEdit.applyChange` &c.) writes directly into
  // `entry.args` and relies on `assignStableKeys` having wrapped it in a
  // `trackedObject` for reactivity. Spread also runs the source proxy's
  // getters so we materialise current values, and `stripNullish` enforces
  // the "cleared field = key omitted" contract — older versions of the
  // write path could persist `null`, this self-heals on draft entry.
  clone.args = stripNullish({ ...(entry.args ?? {}) });
  if (entry.containerArgs) {
    clone.containerArgs = cloneContainerArgs(entry.containerArgs);
  }
  // A composite's per-part overrides must be cloned so draft edits to one
  // part's override don't leak back into the underlying layer.
  if (entry.overrides) {
    clone.overrides = cloneOverrides(entry.overrides);
  }
  if (entry.children?.length) {
    clone.children = entry.children.map(cloneEntryForDraft);
  }
  return clone;
}

/**
 * Removes keys whose value is `null` or `undefined`. Used to enforce the
 * editor's "cleared field = key omitted" contract on freshly-cloned args
 * objects — `""`, `0`, `false` are kept as valid scalar values.
 *
 * @param {Object} obj - Mutated in place; also returned for chaining.
 * @returns {Object}
 */
function stripNullish(obj) {
  for (const key of Object.keys(obj)) {
    if (obj[key] == null) {
      delete obj[key];
    }
  }
  return obj;
}

/**
 * Removes the soft-failure stamps core's permissive validator may have
 * written onto an entry (`__failureType`, `__failureReason`, `__visible`,
 * `__failureDetails`). Used both when cloning an entry for the draft layer
 * (the source layer's stamps don't apply to the draft) and after a live arg
 * mutation (the outline / inspector read these directly and validation only
 * re-runs on layer republish, so stale stamps would persist past the
 * underlying fix).
 *
 * `__failureDetails` is the structured per-failure list the inspector reads
 * to render its errors (the outline reads the `__failureType` /
 * `__failureReason` summary). Clearing it here is what lets a constraint
 * error (e.g. "set at least one of …") drop off the inspector the moment an
 * inline edit makes the block valid, rather than lingering until republish.
 *
 * @param {Object} entry - Mutated in place.
 */
export function clearValidatorStamps(entry) {
  delete entry.__failureType;
  delete entry.__failureReason;
  delete entry.__visible;
  delete entry.__failureDetails;
}

/**
 * Re-runs arg + constraint validation for a single entry against its
 * CURRENT args and updates its soft-failure stamps to match — the
 * edit-time counterpart to the full republish validation pass.
 *
 * Use this in place of a bare `clearValidatorStamps` on the arg-write
 * paths: clearing alone drops the error optimistically on any edit, so a
 * still-invalid block (e.g. a required field left empty, or the last of an
 * `atLeastOne` pair removed) would look fixed until the next republish.
 * Re-validating keeps the current error visible and lets a genuine fix
 * clear it immediately.
 *
 * When the entry is valid — or its block exposes no metadata to validate
 * against (e.g. a string-referenced block) — the stamps are cleared.
 * Otherwise `__failureDetails` (read by the inspector) plus the
 * `__failureType` / `__failureReason` summary (read by the outline) are
 * set from the current failures. `__visible` is deliberately left untouched
 * so the block the author is actively editing stays on the canvas; hiding
 * invalid blocks is the republish pass's job, not this path's.
 *
 * @param {Object} entry - Mutated in place.
 * @param {Object} [options]
 * @param {Object} [options.owner] - Ember owner, forwarded to arg
 *   validation for `model:*` `instanceOf` checks.
 */
export function revalidateEntryStamps(entry, { owner } = {}) {
  if (!entry) {
    return;
  }

  const details = entry.block
    ? collectEntryFailures(entry, entry.block, { owner })
    : [];

  if (details.length === 0) {
    clearValidatorStamps(entry);
    return;
  }

  entry.__failureDetails = details;
  entry.__failureType = "structural-invalid";
  entry.__failureReason = friendlyErrorMessage(details[0]);
  delete entry.__visible;
}

/**
 * Builds a fresh entry POJO from `entry` with `overrides` merged on top
 * and the validator's soft-failure stamps cleared. Every mutation helper
 * in this file that produces a new entry shell via spread goes through
 * here so the next republish's validator starts from a clean slate —
 * without this the previous pass's `__failureType` / `__failureReason`
 * would survive on the new POJO (own-enumerable, copied by spread) and
 * the outline / chrome would keep painting the old error after the
 * underlying issue is fixed.
 *
 * @param {Object} entry
 * @param {Object} overrides
 * @returns {Object}
 */
function cloneEntryShell(entry, overrides) {
  const clone = { ...entry, ...overrides };
  clearValidatorStamps(clone);
  return clone;
}

/**
 * Deep-clones an entry for paste-style insertion: structurally identical
 * to `cloneEntryForDraft`, but strips `__stableKey` recursively so the
 * pasted subtree gets fresh keys minted at publish time. Without this,
 * the clipboard payload would re-use the source's keys and any
 * subsequent move of the original would also re-target the paste (they'd
 * be addressed by the same key).
 *
 * @param {Object} entry
 * @returns {Object}
 */
export function cloneEntryForPaste(entry) {
  const clone = { ...entry };
  delete clone.__stableKey;
  // Drop source-layer validator stamps for the same reason
  // `cloneEntryForDraft` does — pasting republishes the layout, the new
  // validator pass is the source of truth, and stale stamps would paint
  // an error on the pasted entry before validation re-runs.
  clearValidatorStamps(clone);
  if (entry.args) {
    clone.args = { ...entry.args };
  }
  if (entry.containerArgs) {
    clone.containerArgs = cloneContainerArgs(entry.containerArgs);
  }
  if (entry.children?.length) {
    clone.children = entry.children.map(cloneEntryForPaste);
  }
  return clone;
}

/**
 * Two-level clone of a `containerArgs` object. The top-level bag and each
 * namespace's inner object are both fresh references so the draft / paste
 * layer can mutate them without leaking back to the source.
 *
 * @param {Object} containerArgs
 * @returns {Object}
 */
function cloneContainerArgs(containerArgs) {
  const clone = {};
  for (const namespace of Object.keys(containerArgs)) {
    const bag = containerArgs[namespace];
    clone[namespace] =
      bag !== null && typeof bag === "object" ? stripNullish({ ...bag }) : bag;
  }
  return clone;
}

/**
 * Resolves whether an entry's block is the builtin `layout` block. Handles
 * both string refs (`"layout"`) and class refs (whose decorator-assigned
 * `blockName` is `"layout"`), so a layout reloaded from disk (string-only)
 * and one freshly registered from a class both match.
 *
 * @param {Object} entry
 * @returns {boolean}
 */
function isLayoutBlockEntry(entry) {
  if (!entry) {
    return false;
  }
  if (typeof entry.block === "string") {
    return entry.block === "layout";
  }
  if (entry.block) {
    return getBlockMetadata(entry.block)?.blockName === "layout";
  }
  return false;
}

/**
 * Normalizes an outlet's layout to the editor's single-root-layout invariant:
 * the returned array is exactly `[rootLayout]`, where `rootLayout` is the
 * builtin `layout` block whose `children` are the outlet's blocks. This is
 * what lets the editor treat an outlet as an implicit layout — selectable,
 * with a switchable mode — by reusing the ordinary `layout` block rather than
 * a parallel outlet-level layout model.
 *
 * No-ops when the layout is already a single `layout` block at the root (e.g.
 * a layout previously saved in this normalized shape), so re-entering the
 * editor never nests a second wrapper. Otherwise every existing top-level
 * entry becomes a child of a fresh `stack` root layout — a flat list renders
 * identically to the default stack, so wrapping is visually transparent until
 * the author changes the mode.
 *
 * Children keep their identity (`__stableKey` and block references) so
 * selection and DOM identity survive the wrap.
 *
 * @param {Array<Object>} layout
 * @returns {Array<Object>}
 */
export function wrapAsOutletRoot(layout) {
  const entries = layout ?? [];
  if (entries.length === 1 && isLayoutBlockEntry(entries[0])) {
    return entries;
  }
  return [{ block: "layout", args: { mode: "stack" }, children: entries }];
}

/**
 * Resolves an entry's block to its registered name, for either a string ref
 * (`"layout"`) or a decorated class ref (whose `blockName` is the name).
 *
 * @param {Object} entry
 * @returns {string|null}
 */
function blockEntryName(entry) {
  if (typeof entry?.block === "string") {
    return entry.block;
  }
  if (entry?.block) {
    return getBlockMetadata(entry.block)?.blockName ?? null;
  }
  return null;
}

/**
 * The single block kind a container forces every direct child to be, or null.
 * A container opts in by declaring a one-entry `childBlocks` allow-list whose
 * kind is itself a container (so a non-conforming child can be wrapped in it).
 * This is what makes a container's children implicit layouts — the same idea as
 * the outlet's implicit root layout, applied per child.
 *
 * @param {Object} entry - The container entry.
 * @param {(blockRef: string|Function) => (Object|null)} lookupMetadata
 * @returns {string|null}
 */
function singleImplicitChildKind(entry, lookupMetadata) {
  const childBlocks = lookupMetadata?.(entry.block)?.childBlocks;
  if (childBlocks?.length !== 1) {
    return null;
  }
  const kind = childBlocks[0];
  // Only auto-wrap into a container kind — a leaf kind couldn't hold the child.
  return lookupMetadata?.(kind)?.isContainer ? kind : null;
}

/**
 * Recursively enforces every implicit-child-kind container's invariant: each
 * direct child must be of the declared kind, so a container whose `childBlocks`
 * names one container kind (e.g. a tabbed container forcing `layout` panels)
 * yields rich child containers out of the box. Any non-conforming child is
 * wrapped in a fresh instance of the kind.
 *
 * Identity-preserving: returns the SAME array / entry references wherever
 * nothing needs wrapping, so it is a cheap no-op on republish and never churns
 * an unaffected subtree (and re-wrapping is impossible — an already-conforming
 * child is left untouched, so the pass is idempotent). A wrapped child is held
 * by REFERENCE inside the wrapper (never cloned), so a caller holding the
 * original entry — e.g. to select it right after an insert — keeps a live
 * reference into the published tree.
 *
 * @param {Array<Object>} layout
 * @param {(blockRef: string|Function) => (Object|null)} lookupMetadata
 * @returns {Array<Object>}
 */
export function normalizeImplicitChildren(layout, lookupMetadata) {
  if (!Array.isArray(layout) || layout.length === 0) {
    return layout;
  }
  let changed = false;
  const next = layout.map((entry) => {
    const normalized = normalizeEntryImplicitChildren(entry, lookupMetadata);
    if (normalized !== entry) {
      changed = true;
    }
    return normalized;
  });
  return changed ? next : layout;
}

/**
 * Normalizes a single entry's subtree: descendants first, then this container's
 * own implicit-child-kind invariant. Returns the same `entry` reference when
 * nothing changed.
 *
 * @param {Object} entry
 * @param {(blockRef: string|Function) => (Object|null)} lookupMetadata
 * @returns {Object}
 */
function normalizeEntryImplicitChildren(entry, lookupMetadata) {
  if (!entry?.children?.length) {
    return entry;
  }
  let children = normalizeImplicitChildren(entry.children, lookupMetadata);
  const kind = singleImplicitChildKind(entry, lookupMetadata);
  if (kind) {
    let wrapped = false;
    const mapped = children.map((child) => {
      if (blockEntryName(child) === kind) {
        return child;
      }
      wrapped = true;
      // `containerArgs` is the DIRECT parent's placement metadata (e.g. a tab
      // label). After wrapping, the wrapper — not the child — is the parent's
      // direct child, so move the bag onto the wrapper or the parent reads
      // nothing and the label is orphaned one level too deep on the child. A
      // freshly-inserted block carries no `containerArgs`, so its reference is
      // preserved (selection-after-insert relies on it — see the function doc);
      // only a child that already has placement is shallow-cloned to strip it.
      if (child.containerArgs) {
        const { containerArgs, ...rest } = child;
        return { block: kind, args: {}, containerArgs, children: [rest] };
      }
      return { block: kind, args: {}, children: [child] };
    });
    if (wrapped) {
      children = mapped;
    }
  }
  if (children === entry.children) {
    return entry;
  }
  return cloneEntryShell(entry, { children });
}

/**
 * Serializes a layout for transport to the server (the
 * `block_layout`-shaped JSON the `Themes::SaveBlockLayout` endpoint
 * expects). Strips internal bookkeeping (`__stableKey`) and resolves any
 * `entry.block` class references back to their registered names — the
 * server stores layouts as strings, not class references.
 *
 * @param {Array<Object>} layout
 * @returns {Array<Object>}
 */
export function serializeLayoutForSave(layout) {
  return layout.map(serializeEntryForSave);
}

/**
 * True when `prev` and `next` represent the same arg value. Plain strings
 * (the common unformatted case) compare with `Object.is`. Non-string values
 * may be doc-JSON — `toStorage(doc.toJSON())` returns a fresh object each
 * commit, so reference equality always fails even when the content hasn't
 * changed. Fall back to a deep-equal via `JSON.stringify`: doc-JSON is plain
 * (no cycles, no functions) and is serialised with a deterministic key order
 * for the same shape.
 *
 * Used to gate undo pushes so a no-op write (e.g. arrow-walking through a
 * bolded paragraph, or re-selecting an icon that's already set) doesn't
 * pollute the undo stack.
 *
 * @param {*} prev
 * @param {*} next
 * @returns {boolean}
 */
export function sameValue(prev, next) {
  if (Object.is(prev, next)) {
    return true;
  }
  if (typeof prev === "string" || typeof next === "string") {
    return false;
  }
  return JSON.stringify(prev) === JSON.stringify(next);
}

/**
 * Serialises a single entry into the same JSON-safe shape
 * `serializeLayoutForSave` emits, but exported separately so callers
 * (e.g. the inspector's Raw JSON tab) can produce a clean view of one
 * entry without having to walk a whole layout.
 *
 * @param {Object} entry
 * @returns {Object}
 */
export function serializeEntryForSave(entry) {
  const out = {};
  if (typeof entry.block === "string") {
    out.block = entry.block;
  } else if (entry.block) {
    const blockName = getBlockMetadata(entry.block)?.blockName;
    out.block = blockName ?? entry.block.name;
  }
  if (entry.args && Object.keys(entry.args).length > 0) {
    out.args = { ...entry.args };
  }
  if (entry.id != null) {
    out.id = entry.id;
  }
  if (entry.classNames != null) {
    out.classNames = entry.classNames;
  }
  if (entry.containerArgs != null) {
    out.containerArgs = { ...entry.containerArgs };
  }
  if (entry.conditions != null) {
    out.conditions = entry.conditions;
  }
  // Per-part overrides for a composite (a block that renders a code-defined
  // composition). Keyed by a dot-delimited part-id path, each value the inner
  // block's own args. Persisted only for entries that aren't detached — a
  // detached composite carries explicit `children` instead.
  if (entry.overrides && Object.keys(entry.overrides).length > 0) {
    out.overrides = cloneOverrides(entry.overrides);
  }
  if (entry.children?.length) {
    out.children = entry.children.map(serializeEntryForSave);
  }
  return out;
}

/**
 * Shallow-per-path clone of a composite's `overrides` map: a fresh top-level
 * object whose values (each a part's own args object) are themselves copied,
 * so a draft can mutate one part's override without leaking into the source.
 *
 * @param {Object} overrides
 * @returns {Object}
 */
function cloneOverrides(overrides) {
  const clone = {};
  for (const path of Object.keys(overrides)) {
    const argsForPath = overrides[path];
    clone[path] =
      argsForPath && typeof argsForPath === "object"
        ? { ...argsForPath }
        : argsForPath;
  }
  return clone;
}
