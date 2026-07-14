// @ts-check
import {
  classifyNode,
  readAt,
  writeAt,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";

/**
 * Higher-level tree manipulation primitives for the conditions tree
 * editor. Wraps the path-based primitives in `condition-tree.js` with
 * shape-aware operations the UI thinks in:
 *
 *   - groups (AND / OR / NOT) with a children list
 *   - leaves
 *
 * The schema shape stays the same throughout — these helpers never
 * introduce new node kinds, they just smooth over the asymmetric
 * encodings (AND is a bare array; OR uses an `any` key; NOT wraps a
 * single node OR an array). See `condition-tree.js` for the full
 * shape contract.
 */

/**
 * Whether the node is a group combinator (`and` / `or` / `not`).
 *
 * @param {*} node
 * @returns {boolean}
 */
export function isGroup(node) {
  const kind = classifyNode(node);
  return kind === "and" || kind === "or" || kind === "not";
}

/**
 * Whether the node is a leaf condition (`{type, ...args}`).
 *
 * @param {*} node
 * @returns {boolean}
 */
export function isLeaf(node) {
  return classifyNode(node) === "leaf";
}

/**
 * Resolves the combinator of a group node. Returns `null` when the
 * node isn't a group.
 *
 * @param {*} node
 * @returns {"and"|"or"|"not"|null}
 */
export function combinatorOf(node) {
  const kind = classifyNode(node);
  return kind === "and" || kind === "or" || kind === "not" ? kind : null;
}

/**
 * Returns the children list of a group as a plain array. For `NOT` the
 * single-child shape `{not: leaf}` is normalised into `[leaf]` so the
 * UI can render uniformly; multi-child NOT (`{not: [a, b]}`) is
 * returned as-is.
 *
 * @param {*} node
 * @returns {Array<*>}
 */
export function childrenOf(node) {
  const kind = classifyNode(node);
  if (kind === "and") {
    return node;
  }
  if (kind === "or") {
    return node.any;
  }
  if (kind === "not") {
    return Array.isArray(node.not) ? node.not : [node.not];
  }
  return [];
}

/**
 * Builds the absolute path to the Nth child of a group, given the
 * group's own path. Hides the per-combinator asymmetry from callers.
 *
 * @param {Array<string|number>} groupPath
 * @param {*} group
 * @param {number} index
 * @returns {Array<string|number>}
 */
export function childPath(groupPath, group, index) {
  const kind = classifyNode(group);
  if (kind === "and") {
    return [...groupPath, index];
  }
  if (kind === "or") {
    return [...groupPath, "any", index];
  }
  if (kind === "not") {
    if (Array.isArray(group.not)) {
      return [...groupPath, "not", index];
    }
    // Single-child NOT has exactly one child at the `"not"` segment.
    return [...groupPath, "not"];
  }
  return groupPath;
}

/**
 * Appends a node onto the group at `groupPath`. When `groupPath` is
 * empty the operation rewrites the root tree.
 *
 * @param {*} tree
 * @param {Array<string|number>} groupPath
 * @param {*} child
 * @returns {*}
 */
export function insertChild(tree, groupPath, child) {
  const group = groupPath.length === 0 ? tree : readAt(tree, groupPath);
  const next = appendToGroup(group, child);
  if (next == null) {
    return tree;
  }
  return groupPath.length === 0 ? next : writeAt(tree, groupPath, next);
}

/**
 * Adds a fresh empty group of the given combinator as a child of the
 * group at `groupPath`. NOT groups seed with a default leaf so the
 * evaluator can still parse them.
 *
 * @param {*} tree
 * @param {Array<string|number>} groupPath
 * @param {"and"|"or"|"not"} combinator
 * @returns {*}
 */
export function insertGroup(tree, groupPath, combinator) {
  const child = newEmptyGroup(combinator);
  return insertChild(tree, groupPath, child);
}

/**
 * Adds a fresh leaf of the given type as a child of the group at
 * `groupPath`.
 *
 * @param {*} tree
 * @param {Array<string|number>} groupPath
 * @param {string} typeId
 * @returns {*}
 */
export function insertLeaf(tree, groupPath, typeId) {
  return insertChild(tree, groupPath, { type: typeId });
}

/**
 * Deletes the node at `path`. Returns the new tree, or `null` when
 * the deletion empties the root.
 *
 * @param {*} tree
 * @param {Array<string|number>} path
 * @returns {*}
 */
export function removeAt(tree, path) {
  if (path.length === 0) {
    return null;
  }
  return writeAt(tree, path, undefined) ?? null;
}

/**
 * Converts the group at `path` to a new combinator, preserving its
 * children list. When the path is the root, the entire tree is
 * re-shaped. When the previous node was a leaf (root-level), the leaf
 * is wrapped as the new group's only child.
 *
 * @param {*} tree
 * @param {Array<string|number>} path
 * @param {"and"|"or"|"not"} newCombinator
 * @returns {*}
 */
export function setCombinator(tree, path, newCombinator) {
  const node = path.length === 0 ? tree : readAt(tree, path);
  if (node === undefined) {
    return tree;
  }
  const children = isGroup(node)
    ? childrenOf(node)
    : isLeaf(node)
      ? [node]
      : [];
  const next = buildGroupOf(newCombinator, children);
  if (path.length === 0) {
    return next;
  }
  return writeAt(tree, path, next);
}

/**
 * Replaces the leaf at `path` with `newLeaf`. The new leaf retains
 * the same type or switches to a different one — either way, the
 * commit is a single-node replacement.
 *
 * @param {*} tree
 * @param {Array<string|number>} path
 * @param {Object} newLeaf
 * @returns {*}
 */
export function updateLeaf(tree, path, newLeaf) {
  if (path.length === 0) {
    return newLeaf;
  }
  return writeAt(tree, path, newLeaf);
}

/**
 * Returns the empty schema shape for the given combinator. NOT seeds
 * with a default leaf because the evaluator rejects an empty `not`.
 *
 * @param {"and"|"or"|"not"} combinator
 * @returns {*}
 */
export function newEmptyGroup(combinator) {
  if (combinator === "or") {
    return { any: [] };
  }
  if (combinator === "not") {
    return { not: { type: "user" } };
  }
  return [];
}

/**
 * Builds a group node of the requested combinator carrying the given
 * children list.
 *
 * @param {"and"|"or"|"not"} combinator
 * @param {Array<*>} children
 * @returns {*}
 */
function buildGroupOf(combinator, children) {
  if (combinator === "and") {
    return [...children];
  }
  if (combinator === "or") {
    return { any: [...children] };
  }
  if (combinator === "not") {
    if (children.length === 1) {
      return { not: children[0] };
    }
    return { not: [...children] };
  }
  return children;
}

/**
 * Internal: appends `child` to the group `group`, returning a new
 * group node. Returns `null` when `group` isn't a recognised group
 * shape.
 *
 * @param {*} group
 * @param {*} child
 * @returns {*|null}
 */
function appendToGroup(group, child) {
  const kind = classifyNode(group);
  if (kind === "and") {
    return [...group, child];
  }
  if (kind === "or") {
    return { ...group, any: [...group.any, child] };
  }
  if (kind === "not") {
    if (Array.isArray(group.not)) {
      return { ...group, not: [...group.not, child] };
    }
    // Promoting a single-child NOT to multi-child requires lifting the
    // existing child + the new one into an array. NOT-of-AND semantics
    // — equivalent to the previous tree because `{not: A}` already
    // implies "NOT A" and `{not: [A, B]}` implies "NOT (A AND B)".
    return { ...group, not: [group.not, child] };
  }
  return null;
}
