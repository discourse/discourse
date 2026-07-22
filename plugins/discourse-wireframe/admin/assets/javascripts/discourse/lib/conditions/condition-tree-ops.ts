import {
  classifyNode,
  type ConditionCombinator,
  type ConditionGroup,
  type ConditionLeaf,
  type ConditionNode,
  type ConditionPath,
  type ConditionTree,
  type NotCondition,
  type OrCondition,
  readAt,
  writeAt,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";

/**
 * Higher-level tree manipulation primitives for the conditions tree
 * editor. Wraps the path-based primitives in `condition-tree.ts` with
 * shape-aware operations the UI thinks in:
 *
 *   - groups (AND / OR / NOT) with a children list
 *   - leaves
 *
 * The schema shape stays the same throughout — these helpers never
 * introduce new node kinds, they just smooth over the asymmetric
 * encodings (AND is a bare array; OR uses an `any` key; NOT wraps a
 * single node OR an array). See `condition-tree.ts` for the full
 * shape contract.
 */

/**
 * Whether the node is a group combinator (`and` / `or` / `not`).
 *
 * @param node - The value to check.
 * @returns Whether the value is a condition group.
 */
export function isGroup(node: unknown): node is ConditionGroup {
  const kind = classifyNode(node);
  return kind === "and" || kind === "or" || kind === "not";
}

/**
 * Whether the node is a leaf condition (`{type, ...args}`).
 *
 * @param node - The value to check.
 * @returns Whether the value is a condition leaf.
 */
export function isLeaf(node: unknown): node is ConditionLeaf {
  return classifyNode(node) === "leaf";
}

/**
 * Resolves the combinator of a group node. Returns `null` when the
 * node isn't a group.
 *
 * @param node - The value to inspect.
 * @returns The node's combinator, or `null` for a non-group.
 */
export function combinatorOf(node: unknown): ConditionCombinator | null {
  const kind = classifyNode(node);
  return kind === "and" || kind === "or" || kind === "not" ? kind : null;
}

/**
 * Returns the children list of a group as a plain array. For `NOT` the
 * single-child shape `{not: leaf}` is normalised into `[leaf]` so the
 * UI can render uniformly; multi-child NOT (`{not: [a, b]}`) is
 * returned as-is.
 *
 * @param node - The value to inspect.
 * @returns The group's children, or an empty array for a non-group.
 */
export function childrenOf(node: unknown): ConditionNode[] {
  if (Array.isArray(node)) {
    return node;
  }
  if (isOrCondition(node)) {
    return node.any;
  }
  if (isNotCondition(node)) {
    return Array.isArray(node.not) ? node.not : [node.not];
  }
  return [];
}

/**
 * Builds the absolute path to the Nth child of a group, given the
 * group's own path. Hides the per-combinator asymmetry from callers.
 *
 * @param groupPath - The group's absolute path.
 * @param group - The group containing the child.
 * @param index - The child's index in the normalised children list.
 * @returns The child's absolute path.
 */
export function childPath(
  groupPath: ConditionPath,
  group: ConditionGroup,
  index: number
): ConditionPath {
  if (Array.isArray(group)) {
    return [...groupPath, index];
  }
  if (isOrCondition(group)) {
    return [...groupPath, "any", index];
  }
  if (isNotCondition(group)) {
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
 * @param tree - The condition tree to update.
 * @param groupPath - The absolute path to the target group.
 * @param child - The node to append.
 * @returns A new tree, or the original tree for a missing group.
 */
export function insertChild(
  tree: ConditionTree,
  groupPath: ConditionPath,
  child: ConditionNode
): ConditionTree {
  const group = groupPath.length === 0 ? tree : readAt(tree, groupPath);
  const next = appendToGroup(group ?? undefined, child);
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
 * @param tree - The condition tree to update.
 * @param groupPath - The absolute path to the target group.
 * @param combinator - The combinator for the new group.
 * @returns The updated condition tree.
 */
export function insertGroup(
  tree: ConditionTree,
  groupPath: ConditionPath,
  combinator: ConditionCombinator
): ConditionTree {
  const child = newEmptyGroup(combinator);
  return insertChild(tree, groupPath, child);
}

/**
 * Adds a fresh leaf of the given type as a child of the group at
 * `groupPath`.
 *
 * @param tree - The condition tree to update.
 * @param groupPath - The absolute path to the target group.
 * @param typeId - The registered type for the new leaf.
 * @returns The updated condition tree.
 */
export function insertLeaf(
  tree: ConditionTree,
  groupPath: ConditionPath,
  typeId: string
): ConditionTree {
  return insertChild(tree, groupPath, { type: typeId });
}

/**
 * Deletes the node at `path`. Returns the new tree, or `null` when
 * the deletion empties the root.
 *
 * @param tree - The condition tree to update.
 * @param path - The absolute path to remove.
 * @returns The updated tree, or `null` when the root is cleared.
 */
export function removeAt(
  tree: ConditionTree,
  path: ConditionPath
): ConditionNode | null {
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
 * @param tree - The condition tree to update.
 * @param path - The absolute path to the node being converted.
 * @param newCombinator - The replacement combinator.
 * @returns The reshaped condition tree.
 */
export function setCombinator(
  tree: ConditionTree,
  path: ConditionPath,
  newCombinator: ConditionCombinator
): ConditionTree {
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
 * @param tree - The condition tree to update.
 * @param path - The absolute path to the leaf.
 * @param newLeaf - The replacement leaf.
 * @returns The updated condition tree.
 */
export function updateLeaf(
  tree: ConditionTree,
  path: ConditionPath,
  newLeaf: ConditionLeaf
): ConditionTree {
  if (path.length === 0) {
    return newLeaf;
  }
  return writeAt(tree, path, newLeaf);
}

/**
 * Returns the empty schema shape for the given combinator. NOT seeds
 * with a default leaf because the evaluator rejects an empty `not`.
 *
 * @param combinator - The combinator to initialise.
 * @returns The empty group shape for the combinator.
 */
export function newEmptyGroup(combinator: ConditionCombinator): ConditionGroup {
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
 * @param combinator - The combinator to build.
 * @param children - The child nodes to preserve.
 * @returns A group containing the supplied children.
 */
function buildGroupOf(
  combinator: ConditionCombinator,
  children: ConditionNode[]
): ConditionGroup {
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
  // Defensive fallback for an unexpected combinator: the original runtime
  // returns the children list unchanged rather than throwing.
  return children;
}

/**
 * Internal: appends `child` to the group `group`, returning a new
 * group node. Returns `null` when `group` isn't a recognised group
 * shape.
 *
 * @param group - The value expected to be a group.
 * @param child - The node to append.
 * @returns The updated group, or `null` for an unrecognised shape.
 */
function appendToGroup(
  group: ConditionNode | undefined,
  child: ConditionNode
): ConditionGroup | null {
  if (Array.isArray(group)) {
    return [...group, child];
  }
  if (isOrCondition(group)) {
    return { ...group, any: [...group.any, child] };
  }
  if (isNotCondition(group)) {
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

/**
 * Checks whether a value has the OR combinator shape.
 *
 * @param node - The value to check.
 * @returns Whether the value contains an `any` child array.
 */
function isOrCondition(node: unknown): node is OrCondition {
  return (
    typeof node === "object" &&
    node !== null &&
    !Array.isArray(node) &&
    Array.isArray(Reflect.get(node, "any"))
  );
}

/**
 * Checks whether a value has the NOT combinator shape.
 *
 * @param node - The value to check.
 * @returns Whether the value contains a `not` child node.
 */
function isNotCondition(node: unknown): node is NotCondition {
  return (
    typeof node === "object" &&
    node !== null &&
    !Array.isArray(node) &&
    Reflect.get(node, "not") !== undefined
  );
}
