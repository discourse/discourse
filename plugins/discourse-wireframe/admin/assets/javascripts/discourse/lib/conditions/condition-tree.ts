import type BlocksService from "discourse/services/blocks";

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

export const COMBINATOR_KINDS = ["and", "or", "not"] as const;

/** A combinator supported by the conditions editor. */
export type ConditionCombinator = (typeof COMBINATOR_KINDS)[number];

/** A segment in the editor's path representation. */
export type ConditionPathSegment = number | "any" | "not";

/** An absolute path from the condition-tree root to a node. */
export type ConditionPath = ConditionPathSegment[];

/** A condition leaf while it is being authored. */
export type ConditionLeaf = {
  /** The registered condition type, or unset before the author chooses one. */
  type?: string;

  /** A condition-specific argument keyed by its schema name. */
  [argumentName: string]: unknown;
};

/** An implicit-AND condition group. */
export type AndCondition = ConditionNode[];

/** An OR condition group. */
export type OrCondition = {
  /** Child nodes, at least one of which must pass. */
  any: ConditionNode[];
};

/** A NOT condition group. */
export type NotCondition = {
  /** The child node whose result is inverted. */
  not: ConditionNode;
};

/** A combinator node in the conditions editor. */
export type ConditionGroup = AndCondition | OrCondition | NotCondition;

/** A node accepted by the conditions editor. */
export type ConditionNode = ConditionLeaf | ConditionGroup;

/** The optional condition tree stored on a layout entry. */
export type ConditionTree = ConditionNode | null | undefined;

/** A condition descriptor returned by the canonical blocks service. */
export type ConditionTypeMeta = ReturnType<
  BlocksService["listConditionTypes"]
>[number];

/**
 * Checks whether a runtime value is an optional condition tree.
 *
 * @param value - Runtime value to inspect.
 * @returns Whether the value is absent or has a condition-node shape.
 */
export function isConditionTree(value: unknown): value is ConditionTree {
  return value == null || isConditionNode(value);
}

/** The renderer category for a value at a condition-tree position. */
export type ConditionNodeKind =
  | "empty"
  | "and"
  | "or"
  | "not"
  | "leaf"
  | "unknown";

// TODO(devxp-typescript-pending): replace these editor-domain condition types
// with the canonical core condition-spec types once `LayoutEntry.conditions`
// exports its recursive leaf/AND/OR/NOT schema instead of `object | object[]`.

/**
 * Classifies a node so the renderer can decide which row to draw.
 *
 * @param node - The untrusted value to classify.
 * @returns The renderer category for the value.
 */
export function classifyNode(node: unknown): ConditionNodeKind {
  if (node == null) {
    return "empty";
  }
  if (Array.isArray(node)) {
    return "and";
  }
  if (typeof node !== "object") {
    return "unknown";
  }
  if (Array.isArray(Reflect.get(node, "any"))) {
    return "or";
  }
  if (Reflect.get(node, "not") !== undefined) {
    return "not";
  }
  if (typeof Reflect.get(node, "type") === "string") {
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
 * @param typeId - The registered condition type identifier.
 * @returns An argless leaf for the condition type.
 */
export function emptyLeaf(typeId: string): ConditionLeaf {
  return { type: typeId };
}

/**
 * Returns an empty AND combinator (the simplest array form).
 *
 * @returns An empty implicit-AND group.
 */
export function emptyAnd(): AndCondition {
  return [];
}

/**
 * Returns an empty OR combinator.
 *
 * @returns An empty OR group.
 */
export function emptyOr(): OrCondition {
  return { any: [] };
}

/**
 * Returns a default-shaped NOT combinator wrapping an `empty` leaf. The
 * caller is responsible for prompting the author to pick a real child
 * type before save.
 *
 * @returns A NOT group seeded with a default leaf.
 */
export function emptyNot(): NotCondition {
  return { not: { type: "user" } };
}

/**
 * Reads the node at `path` inside `tree`. Returns `undefined` for
 * out-of-range paths so callers can no-op without throwing.
 *
 * @param tree - The condition tree to traverse.
 * @param path - The absolute path to read.
 * @returns The node at the path, or `undefined` when the path is missing.
 */
export function readAt(
  tree: ConditionTree,
  path: ConditionPath
): ConditionNode | undefined {
  let node: unknown = tree;
  for (const seg of path) {
    if (node == null) {
      return undefined;
    }
    if (seg === "not") {
      if (typeof node !== "object") {
        return undefined;
      }
      node = Reflect.get(node, "not");
      continue;
    }
    if (seg === "any") {
      if (typeof node !== "object") {
        return undefined;
      }
      node = Reflect.get(node, "any");
      continue;
    }
    if (Array.isArray(node)) {
      node = node[seg];
      continue;
    }
    return undefined;
  }
  // TODO(devxp-typescript-pending): the original runtime returns the resolved
  // value at the path as-is (which may not have a node shape when the path
  // lands on a raw value); cast rather than filtering it out.
  return node as ConditionNode | undefined;
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
 * @param tree - The condition tree to update.
 * @param path - The absolute path to replace.
 * @param replacement - The replacement node, or `undefined` to remove it.
 * @returns A new tree, or the same tree when the path was missing.
 */
export function writeAt(
  tree: ConditionTree,
  path: ConditionPath,
  replacement: ConditionNode | undefined
): ConditionTree {
  if (path.length === 0) {
    return replacement;
  }
  const [head, ...rest] = path;

  if (head === "not") {
    if (replacement === undefined) {
      // Removing a NOT's only child collapses the NOT itself.
      return undefined;
    }
    const child = writeAt(readProperty(tree, "not"), rest, replacement);
    return { ...propertiesOf(tree), not: child };
  }

  if (head === "any") {
    return {
      ...propertiesOf(tree),
      any: writeAt(readProperty(tree, "any"), rest, replacement),
    };
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
    // TODO(devxp-typescript-pending): the original runtime writes the raw
    // recursion result (which may be `undefined` when the child collapses)
    // into the slot; cast rather than guard so removal semantics are preserved.
    next[idx] = child as ConditionNode;
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
 * @param tree - The condition tree to update.
 * @param path - Path to the combinator node.
 * @param child - The child node to append.
 * @returns A new tree, or the original tree for a non-group target.
 */
export function appendChild(
  tree: ConditionTree,
  path: ConditionPath,
  child: ConditionNode
): ConditionTree {
  const target = path.length === 0 ? tree : readAt(tree, path);
  let nextTarget;
  if (Array.isArray(target)) {
    nextTarget = [...target, child];
  } else if (isOrCondition(target)) {
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
 * @param tree - The tree to wrap.
 * @param kind - The combinator to create.
 * @returns The tree reshaped under the requested combinator.
 */
export function wrapIn(
  tree: ConditionTree,
  kind: ConditionCombinator
): ConditionNode {
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
  // TODO(devxp-typescript-pending): defensive fallback for an unexpected kind;
  // the original runtime returns the tree unchanged (which may be nullish), so
  // cast rather than substituting an empty array.
  return tree as ConditionNode;
}

/**
 * Checks whether a runtime value is a node shape the editor can traverse.
 *
 * @param value - The value to check.
 * @returns Whether the value is an object or array node.
 */
function isConditionNode(value: unknown): value is ConditionNode {
  return typeof value === "object" && value !== null;
}

/**
 * Checks whether a node uses the OR combinator shape.
 *
 * @param node - The node to check.
 * @returns Whether the node has an `any` child array.
 */
function isOrCondition(node: ConditionTree): node is OrCondition {
  return (
    typeof node === "object" &&
    node !== null &&
    !Array.isArray(node) &&
    Array.isArray(Reflect.get(node, "any"))
  );
}

/**
 * Reads a child property without assuming the tree has the matching shape.
 *
 * @param tree - The tree value to inspect.
 * @param key - The combinator child property.
 * @returns The child node when present.
 */
function readProperty(tree: ConditionTree, key: "any" | "not"): ConditionTree {
  // Runtime-equivalent to `tree?.[key]`: returns the raw child value without
  // asserting its shape, so a malformed child is passed through unchanged.
  if (tree == null) {
    return undefined;
  }
  return Reflect.get(Object(tree), key) as ConditionTree;
}

/**
 * Returns the enumerable properties that object spread would copy.
 *
 * @param tree - The tree value being cloned.
 * @returns The tree's enumerable object properties.
 */
function propertiesOf(tree: ConditionTree): object {
  // Runtime-equivalent to `{ ...tree }`: the enumerable own properties an
  // object spread would copy (nothing for a nullish tree).
  return { ...tree };
}
