// @ts-check
/**
 * Layout-mutation helpers for the visual editor.
 *
 * The editor never mutates registered layout entries in place. Instead, it
 * produces a brand-new layout array (with the affected entry's `args`
 * immutably replaced) and pushes it back through `_replaceLayoutForEditor`.
 * The block system's leaf-render cache compares args by value, so the swap
 * triggers a re-curry and the canvas updates.
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
