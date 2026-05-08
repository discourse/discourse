// @ts-check
/**
 * Layout-mutation helpers for the visual editor.
 *
 * The editor publishes its in-progress edits as a `session-draft` layer via
 * `api.setLayoutLayer`. The draft layout is a deep clone of the resolved
 * layout (preserving `__stableKey` so DOM identity carries over), wrapped at
 * publish time so each draft entry's `args` lands in its own `trackedObject`.
 * Subsequent edits mutate those draft args in place — the trackedObject's
 * compute-ref proxy propagates the change to the rendered block without
 * re-publishing the layer.
 *
 * Drag-drop / palette additions in later phases will use the immutable
 * `replaceEntryArgs` family to build new layouts and republish via
 * `setLayoutLayer`.
 *
 * These helpers are pure logic — no Glimmer, no service injection — so the
 * editor service stays small and the helpers stay testable in isolation.
 */
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

/**
 * Resolves a layout entry's `block` reference to the same composite key the
 * BLOCK_DEBUG callback receives (`${blockName}:${__stableKey}`). When the
 * editor service has a `selectedBlockKey` it compares against this.
 *
 * @param {Object} entry
 * @returns {string|null}
 */
export function entryKey(entry) {
  if (entry?.__stableKey === undefined) {
    return null;
  }
  const blockRef = entry.block;
  if (typeof blockRef === "string") {
    return `${blockRef}:${entry.__stableKey}`;
  }
  const name = getBlockMetadata(blockRef)?.blockName;
  if (!name) {
    return null;
  }
  return `${name}:${entry.__stableKey}`;
}

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
        return { ...entry, args: { ...updater(currentArgs) } };
      }
      if (entry.children?.length) {
        const newChildren = walk(entry.children);
        if (newChildren !== entry.children) {
          subtreeChanged = true;
          return { ...entry, children: newChildren };
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
 * Returns a structural deep clone of a layout suitable for publishing as a
 * `session-draft` layer. The clone preserves each entry's `__stableKey` and
 * passes through immutable references (block class, conditions, classNames,
 * containerArgs, id) by reference. Each entry's `args` is copied into a
 * fresh POJO so that `assignStableKeys` (run by `_setLayoutLayer`) wraps
 * those POJOs in their own `trackedObject` proxies — keeping draft mutations
 * isolated from the underlying layer's args.
 *
 * @param {Array<Object>} layout
 * @returns {Array<Object>}
 */
export function cloneLayoutForDraft(layout) {
  return layout.map(cloneEntryForDraft);
}

function cloneEntryForDraft(entry) {
  const clone = { ...entry };
  if (entry.args) {
    // Spread runs the `trackedObject` proxy's getters, materialising the
    // current values into a fresh plain object that will be re-wrapped at
    // publish time.
    clone.args = { ...entry.args };
  }
  if (entry.children?.length) {
    clone.children = entry.children.map(cloneEntryForDraft);
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

function serializeEntryForSave(entry) {
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
