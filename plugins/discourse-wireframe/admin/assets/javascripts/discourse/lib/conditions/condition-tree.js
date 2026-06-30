// @ts-check

/**
 * Helpers for the visual condition builder to read, write, and traverse
 * the entry-level `conditions` tree the blocks system uses. The tree
 * shape is:
 *
 * - `null` / `undefined` — no conditions.
 * - `[cond, cond, ...]` — implicit AND.
 * - `{ any: [cond, cond, ...] }` — OR.
 * - `{ not: cond }` — NOT (single child).
 * - `{ type: "<id>", ...args }` — a leaf, type discriminates which
 *   condition class evaluates it.
 *
 * Paths into the tree are arrays of segments. Each segment is either a
 * number (array index into an AND list or an `any` list) or one of the
 * sentinels `"not"` (the child of a NOT node) or `"any"` (the list under
 * an OR node).
 */

export const COMBINATOR_KINDS = ["and", "or", "not"];

/**
 * Classifies a node so the renderer can decide which row to draw.
 *
 * @param {*} node
 * @returns {"empty"|"and"|"or"|"not"|"leaf"|"unknown"}
 */
export function classifyNode(node) {
  if (node == null) {
    return "empty";
  }
  if (Array.isArray(node)) {
    return "and";
  }
  if (typeof node !== "object") {
    return "unknown";
  }
  if (Array.isArray(node.any)) {
    return "or";
  }
  if (node.not !== undefined) {
    return "not";
  }
  if (typeof node.type === "string") {
    return "leaf";
  }
  return "unknown";
}

/**
 * Returns a default leaf node for the given type id. The leaf is shaped
 * so the condition evaluator treats it as a fully-formed (if argless)
 * condition — `argsSchema`'s required fields will need to be filled in
 * by the author before the condition validates on save.
 *
 * @param {string} typeId
 * @returns {Object}
 */
export function emptyLeaf(typeId) {
  return { type: typeId };
}

/**
 * Returns an empty AND combinator (the simplest array form).
 *
 * @returns {Array}
 */
export function emptyAnd() {
  return [];
}

/**
 * Returns an empty OR combinator.
 *
 * @returns {{any: Array}}
 */
export function emptyOr() {
  return { any: [] };
}

/**
 * Returns a default-shaped NOT combinator wrapping an `empty` leaf. The
 * caller is responsible for prompting the author to pick a real child
 * type before save.
 *
 * @returns {{not: Object}}
 */
export function emptyNot() {
  return { not: { type: "user" } };
}

/**
 * Reads the node at `path` inside `tree`. Returns `undefined` for
 * out-of-range paths so callers can no-op without throwing.
 *
 * @param {*} tree
 * @param {Array<string|number>} path
 */
export function readAt(tree, path) {
  let node = tree;
  for (const seg of path) {
    if (node == null) {
      return undefined;
    }
    if (seg === "not") {
      node = node.not;
      continue;
    }
    if (seg === "any") {
      node = node.any;
      continue;
    }
    if (Array.isArray(node)) {
      node = node[seg];
      continue;
    }
    return undefined;
  }
  return node;
}

/**
 * Returns a structurally cloned `tree` with the node at `path` replaced
 * by `replacement`. The clone preserves identity on untouched branches
 * so Glimmer's autotracking can short-circuit re-renders.
 *
 * When `replacement` is `undefined`, the node at `path` is removed
 * (spliced from its parent array, or the parent combinator is
 * normalised — e.g. a NOT whose child gets removed becomes a no-op).
 *
 * @param {*} tree
 * @param {Array<string|number>} path
 * @param {*} replacement
 * @returns {*} a new tree (or the same one when the path was missing).
 */
export function writeAt(tree, path, replacement) {
  if (path.length === 0) {
    return replacement;
  }
  const [head, ...rest] = path;

  if (head === "not") {
    if (replacement === undefined) {
      // Removing a NOT's only child collapses the NOT itself.
      return undefined;
    }
    const child = writeAt(tree?.not, rest, replacement);
    return { ...tree, not: child };
  }

  if (head === "any") {
    return { ...tree, any: writeAt(tree?.any, rest, replacement) };
  }

  if (Array.isArray(tree)) {
    const idx = Number(head);
    if (rest.length === 0) {
      const next = [...tree];
      if (replacement === undefined) {
        next.splice(idx, 1);
      } else {
        next[idx] = replacement;
      }
      return next;
    }
    const child = writeAt(tree[idx], rest, replacement);
    const next = [...tree];
    next[idx] = child;
    return next;
  }

  // Defensive fallback: path doesn't match the tree's shape.
  return tree;
}

/**
 * Pushes a new node onto a combinator's children list. Returns a fresh
 * tree with the change applied; identity preserved on untouched
 * branches.
 *
 * @param {*} tree
 * @param {Array<string|number>} path - Path to the combinator node.
 * @param {*} child
 * @returns {*}
 */
export function appendChild(tree, path, child) {
  const target = path.length === 0 ? tree : readAt(tree, path);
  let nextTarget;
  if (Array.isArray(target)) {
    nextTarget = [...target, child];
  } else if (target && Array.isArray(target.any)) {
    nextTarget = { ...target, any: [...target.any, child] };
  } else {
    return tree;
  }
  return writeAt(tree, path, nextTarget);
}

/**
 * Wraps `tree` in a combinator of the requested kind. Used by the
 * builder's "convert" affordance.
 *
 * @param {*} tree
 * @param {"and"|"or"|"not"} kind
 * @returns {*}
 */
export function wrapIn(tree, kind) {
  if (kind === "and") {
    return tree == null ? [] : Array.isArray(tree) ? tree : [tree];
  }
  if (kind === "or") {
    if (tree == null) {
      return { any: [] };
    }
    return Array.isArray(tree) ? { any: tree } : { any: [tree] };
  }
  if (kind === "not") {
    return { not: tree ?? { type: "user" } };
  }
  return tree;
}
