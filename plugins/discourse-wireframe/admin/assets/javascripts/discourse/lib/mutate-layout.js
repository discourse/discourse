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
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
// `entryKey` lives in its own file in the UNIVERSAL bundle so the
// live-page `grid-math.js` can use it without dragging mutate-layout
// (admin-only) into the universal bundle. This file is admin-only; we
// import via the absolute addon path because the universal entry-key
// module isn't reachable via a relative path from this admin location.
// Re-exported so existing call sites that import it from
// `lib/mutate-layout` keep working.
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/entry-key";

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
 * @returns {{layout: Array<Object>, changed: boolean}}
 */
export function replaceEntryInPlace(layout, key, newEntry) {
  let changed = false;

  function walk(entries) {
    let subtreeChanged = false;
    const result = entries.map((entry) => {
      if (entryKey(entry) === key) {
        changed = true;
        subtreeChanged = true;
        return cloneEntryShell(newEntry, { __stableKey: entry.__stableKey });
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
 * written onto an entry (`__failureType`, `__failureReason`, `__visible`).
 * Used both when cloning an entry for the draft layer (the source layer's
 * stamps don't apply to the draft) and after a live arg mutation (the
 * outline / inspector read these directly and validation only re-runs on
 * layer republish, so stale stamps would persist past the underlying fix).
 *
 * @param {Object} entry - Mutated in place.
 */
export function clearValidatorStamps(entry) {
  delete entry.__failureType;
  delete entry.__failureReason;
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
  if (entry.children?.length) {
    out.children = entry.children.map(serializeEntryForSave);
  }
  return out;
}
