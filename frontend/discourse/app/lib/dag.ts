import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";

/**
 * A key or array of keys used to position an item relative to others.
 */
export interface DAGPosition {
  /** A key or array of keys of items which should appear before this one. */
  before?: string | string[];
  /** A key or array of keys of items which should appear after this one. */
  after?: string | string[];
}

export interface DAGOptions<T = unknown> {
  /** Default positioning rules for new items. */
  defaultPosition?: DAGPosition;
  /**
   * Whether to throw an error when a cycle is detected. When false, the
   * default position will be used instead.
   */
  throwErrorOnCycle?: boolean;
  /** Called when an item is added. */
  onAddItem?: (key: string, value: T, position: DAGPosition) => void;
  /** Called when an item is removed. */
  onDeleteItem?: (key: string) => void;
  /** Called when an item is replaced. */
  onReplaceItem?: (
    key: string,
    newValue: T,
    oldValue: T,
    newPosition: DAGPosition | undefined,
    oldPosition: DAGPosition
  ) => void;
  /** Called when an item is repositioned. */
  onRepositionItem?: (
    key: string,
    newPosition: DAGPosition,
    oldPosition: DAGPosition
  ) => void;
}

/**
 * A resolved key/value pair together with its positioning rules, as
 * returned by {@link DAG#resolve}.
 */
export interface DAGResolvedEntry<T = unknown> {
  key: string;
  value: T;
  position: DAGPosition;
}

interface DAGItem<T> {
  value: T;
  before?: string | string[];
  after?: string | string[];
}

interface DAGVertex<T> {
  key: string;
  val: T | undefined;
  inEdges: Set<string>;
  outEdges: Set<string>;
  insertionIdx: number;

  /**
   * The before/after constraints actually applied to the graph for this
   * vertex. They can differ from the item's declared position when a
   * cycle forced a fallback to the default position, and they drive the
   * placement ranks computed by the sort.
   */
  appliedBefore?: string | string[];
  appliedAfter?: string | string[];
}

/* Placement-rank slots: a rank extended with BEFORE_ANCHOR sorts just
   before its anchor, with AFTER_ANCHOR just after it. The anchor itself
   compares as 0 (the implicit padding value in compareRanks). */
const BEFORE_ANCHOR = -1;
const AFTER_ANCHOR = 1;

/**
 * Lexicographic comparison of placement ranks. A rank that runs out of
 * elements compares as 0 from then on, ordering an anchor between its
 * before-extensions (-1, ...) and its after-extensions (1, ...).
 */
function compareRanks(a: number[], b: number[]): number {
  const len = Math.max(a.length, b.length);
  for (let i = 0; i < len; i++) {
    const av = i < a.length ? a[i] : 0;
    const bv = i < b.length ? b[i] : 0;
    if (av !== bv) {
      return av < bv ? -1 : 1;
    }
  }
  return 0;
}

/** Binary min-heap over numbers, used to pop the lowest rank ordinal. */
class MinHeap {
  #heap: number[] = [];

  get size(): number {
    return this.#heap.length;
  }

  push(value: number): void {
    const heap = this.#heap;
    heap.push(value);
    let i = heap.length - 1;
    while (i > 0) {
      const parent = Math.floor((i - 1) / 2);
      if (heap[parent] <= heap[i]) {
        break;
      }
      [heap[parent], heap[i]] = [heap[i], heap[parent]];
      i = parent;
    }
  }

  pop(): number {
    const heap = this.#heap;
    const top = heap[0];
    const last = heap.pop();
    if (heap.length > 0) {
      heap[0] = last;
      let i = 0;
      for (;;) {
        const left = 2 * i + 1;
        const right = left + 1;
        let min = i;
        if (left < heap.length && heap[left] < heap[min]) {
          min = left;
        }
        if (right < heap.length && heap[right] < heap[min]) {
          min = right;
        }
        if (min === i) {
          break;
        }
        [heap[min], heap[i]] = [heap[i], heap[min]];
        i = min;
      }
    }
    return top;
  }
}

class DAGCycleError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DAGCycleError";
  }
}

export default class DAG<T = unknown> {
  /**
   * Creates a new DAG instance from an iterable of entries.
   *
   * @param entriesLike - An iterable of key-value-position tuples to initialize the DAG.
   * @param opts - Optional configuration object.
   * @returns A new DAG instance.
   */
  static from<T = unknown>(
    entriesLike: Iterable<[string, T, DAGPosition?]>,
    opts?: DAGOptions<T>
  ): DAG<T> {
    const dag = new this(opts) as DAG<T>;

    for (const [key, value, position] of entriesLike) {
      dag.add(key, value, position);
    }

    return dag;
  }

  #defaultPosition: DAGPosition;
  #onAddItem?: DAGOptions<T>["onAddItem"];
  #onDeleteItem?: DAGOptions<T>["onDeleteItem"];
  #onReplaceItem?: DAGOptions<T>["onReplaceItem"];
  #onRepositionItem?: DAGOptions<T>["onRepositionItem"];
  #throwErrorOnCycle: boolean;

  #items = new Map<string, DAGItem<T>>();
  #vertices = new Map<string, DAGVertex<T>>();
  #insertionCounter = 0;
  #dirty = true;
  #cachedResolve: DAGResolvedEntry<T>[] | null = null;

  /**
   * Creates a new Directed Acyclic Graph (DAG) instance.
   *
   * @param opts - Optional configuration object.
   */
  constructor(opts?: DAGOptions<T>) {
    this.#defaultPosition = opts?.defaultPosition || {};
    this.#throwErrorOnCycle = opts?.throwErrorOnCycle ?? true;

    this.#onAddItem = opts?.onAddItem;
    this.#onDeleteItem = opts?.onDeleteItem;
    this.#onReplaceItem = opts?.onReplaceItem;
    this.#onRepositionItem = opts?.onRepositionItem;
  }

  /**
   * Adds a key/value pair to the DAG. Can optionally specify before/after position requirements.
   *
   * @param key - The key of the item to be added. Can be referenced by other member's position parameters.
   * @param value - The value of the item to be added.
   * @param position - The position object specifying before/after requirements.
   * @returns True if the item was added, false if the key already exists.
   */
  add(key: string, value: T, position?: DAGPosition): boolean {
    if (this.has(key)) {
      return false;
    }

    position ||= this.#defaultPositionForKey(key);
    const { before, after } = position;

    try {
      this.#addToGraph(key, value, before, after);
    } catch (e) {
      // Roll the graph back to the current items so a failed add leaves nothing behind.
      this.#rebuildGraph();
      throw e;
    }

    this.#items.set(key, { value, before, after });
    this.#dirty = true;
    this.#onAddItem?.(key, value, position);

    return true;
  }

  /**
   * Remove an item from the map by key.
   *
   * @param key - The key of the item to be removed.
   * @returns True if the item was deleted, false otherwise.
   */
  delete(key: string): boolean {
    const deleted = this.#items.delete(key);
    if (deleted) {
      this.#dirty = true;
      this.#rebuildGraph();
      this.#onDeleteItem?.(key);
    }

    return deleted;
  }

  /**
   * Replace an existing item in the map.
   *
   * @param key - The key of the item to be replaced.
   * @param value - The new value of the item.
   * @param position - The new position constraints. If omitted, the existing position is preserved.
   * @returns True if the item was replaced, false otherwise.
   */
  replace(key: string, value: T, position?: DAGPosition): boolean {
    return this.#replace(key, value, position);
  }

  /**
   * Change the positioning rules of an existing item in the map. Will replace all existing rules.
   *
   * @param key - The key of the item to reposition.
   * @param position - The new position constraints. Replaces all existing rules.
   * @returns True if the item was repositioned, false otherwise.
   */
  reposition(key: string, position: DAGPosition): boolean {
    if (!this.has(key) || !position) {
      return false;
    }

    const { value } = this.#items.get(key);

    return this.#replace(key, value, position, { repositionOnly: true });
  }

  /**
   * Check whether an item exists in the map.
   *
   * @param key - The key to check for existence.
   * @returns True if the item exists, false otherwise.
   */
  has(key: string): boolean {
    return this.#items.has(key);
  }

  /**
   * Returns an array of entries in the DAG. Each entry is a tuple containing the key, value, and position object.
   *
   * @returns An array of key-value-position tuples.
   */
  entries(): Array<[string, T, DAGPosition]> {
    return Array.from(this.#items.entries()).map(
      ([key, { value, before, after }]) => [key, value, { before, after }]
    );
  }

  /**
   * Return the resolved key/value pairs in the map. The order of the
   * pairs is determined by the before/after rules using a
   * locality-preserving topological sort.
   *
   * The result is memoized per instance: repeated resolve() calls on an
   * unmutated DAG return the same array (helps the header icon/button
   * singletons that re-resolve on every render).
   *
   * @returns An array of key/value/position objects.
   */
  @bind
  resolve(): DAGResolvedEntry<T>[] {
    if (!this.#dirty && this.#cachedResolve) {
      return this.#cachedResolve;
    }

    const sortedKeys = this.#sort();
    const result: DAGResolvedEntry<T>[] = [];

    for (let i = 0; i < sortedKeys.length; i++) {
      const key = sortedKeys[i];
      if (this.has(key)) {
        const { value, before, after } = this.#items.get(key);
        result.push({ key, value, position: { before, after } });
      }
    }

    this.#dirty = false;
    // Frozen so callers can't mutate the shared cached array in place.
    Object.freeze(result);
    this.#cachedResolve = result;
    return result;
  }

  /* Graph management */

  /**
   * Returns the default position for a given key, excluding any
   * constraints that reference the key itself. This prevents
   * self-loops when the default position happens to mention the
   * same key being added (e.g., adding "search" with a default
   * of `{ before: "search" }` would otherwise create a self-edge).
   *
   * @param key - The key to compute the default position for.
   * @returns The default position with self-references stripped.
   */
  #defaultPositionForKey(key: string): DAGPosition {
    const pos = { ...this.#defaultPosition };
    if (makeArray(pos.before).includes(key)) {
      delete pos.before;
    }
    if (makeArray(pos.after).includes(key)) {
      delete pos.after;
    }
    return pos;
  }

  /**
   * Returns the vertex for the given key, creating a placeholder
   * vertex if one does not exist yet. Placeholder vertices support
   * forward references: a key can appear in a before/after constraint
   * before it is explicitly added via `add()`.
   *
   * @param key - The vertex key.
   * @returns The vertex object.
   */
  #getOrCreateVertex(key: string): DAGVertex<T> {
    let v = this.#vertices.get(key);
    if (v === undefined) {
      v = {
        key,
        val: undefined,
        inEdges: new Set(),
        outEdges: new Set(),
        insertionIdx: -1,
      };
      this.#vertices.set(key, v);
    }
    return v;
  }

  /**
   * Adds a vertex and its edges to the internal graph. When
   * `throwErrorOnCycle` is false, a cycle caused by the requested
   * position will be caught and the item will be re-added using
   * the default position instead.
   *
   * @param key - The vertex key.
   * @param value - The vertex value.
   * @param before - Key(s) this vertex must appear before.
   * @param after - Key(s) this vertex must appear after.
   */
  #addToGraph(
    key: string,
    value: T,
    before?: string | string[],
    after?: string | string[]
  ): void {
    if (this.#throwErrorOnCycle) {
      this.#addVertexAndEdges(key, value, before, after);
    } else {
      try {
        this.#addVertexAndEdges(key, value, before, after);
      } catch (e) {
        if (!(e instanceof DAGCycleError)) {
          throw e;
        }
        const { before: newBefore, after: newAfter } =
          this.#defaultPositionForKey(key);
        try {
          this.#addVertexAndEdges(key, value, newBefore, newAfter);
        } catch (e2) {
          if (!(e2 instanceof DAGCycleError)) {
            throw e2;
          }
          // Both the requested and default positions create a cycle.
          // The vertex exists but has no constraint edges.
        }
      }
    }
  }

  #addVertexAndEdges(
    key: string,
    value: T,
    before?: string | string[],
    after?: string | string[]
  ): void {
    const v = this.#getOrCreateVertex(key);
    v.val = value;
    if (v.insertionIdx === -1) {
      v.insertionIdx = this.#insertionCounter++;
    }

    // Track edges added during this call as [fromKey, toKey] pairs
    // so they can be rolled back if a later constraint creates a cycle.
    const added: string[] = [];

    try {
      if (before) {
        if (typeof before === "string") {
          if (this.#addEdge(v, this.#getOrCreateVertex(before))) {
            added.push(v.key, before);
          }
        } else {
          for (let i = 0; i < before.length; i++) {
            if (this.#addEdge(v, this.#getOrCreateVertex(before[i]))) {
              added.push(v.key, before[i]);
            }
          }
        }
      }

      if (after) {
        if (typeof after === "string") {
          if (this.#addEdge(this.#getOrCreateVertex(after), v)) {
            added.push(after, v.key);
          }
        } else {
          for (let i = 0; i < after.length; i++) {
            if (this.#addEdge(this.#getOrCreateVertex(after[i]), v)) {
              added.push(after[i], v.key);
            }
          }
        }
      }
    } catch (e) {
      for (let i = 0; i < added.length; i += 2) {
        this.#vertices.get(added[i]).outEdges.delete(added[i + 1]);
        this.#vertices.get(added[i + 1]).inEdges.delete(added[i]);
      }
      throw e;
    }

    // Recorded only on success so a cycle fallback re-records the
    // constraints that actually made it into the graph.
    v.appliedBefore = before;
    v.appliedAfter = after;
  }

  #addEdge(from: DAGVertex<T>, to: DAGVertex<T>): boolean {
    if (from.key === to.key) {
      throw new DAGCycleError("cycle detected: " + to.key + " <- " + to.key);
    }

    if (from.outEdges.has(to.key)) {
      return false;
    }

    if (to.outEdges.size > 0) {
      const path = this.#findCyclePath(to, from.key);
      if (path !== null) {
        throw new DAGCycleError("cycle detected: " + path);
      }
    }

    from.outEdges.add(to.key);
    to.inEdges.add(from.key);
    return true;
  }

  #findCyclePath(start: DAGVertex<T>, targetKey: string): string | null {
    if (start.outEdges.has(targetKey)) {
      return targetKey + " <- " + start.key + " <- " + targetKey;
    }

    const visited = new Set([start.key]);
    const parent = new Map<string, string>();
    const frontier: string[] = [];

    for (const next of start.outEdges) {
      if (!visited.has(next)) {
        visited.add(next);
        parent.set(next, start.key);
        frontier.push(next);
      }
    }

    for (let head = 0; head < frontier.length; head++) {
      const key = frontier[head];

      if (key === targetKey) {
        let msg = targetKey;
        let cur: string | undefined = targetKey;
        while (cur !== undefined) {
          msg += " <- " + (parent.get(cur) ?? start.key);
          cur = parent.get(cur);
          if (cur === start.key) {
            break;
          }
        }
        msg += " <- " + targetKey;
        return msg;
      }

      const vertex = this.#vertices.get(key);
      if (vertex) {
        for (const next of vertex.outEdges) {
          if (!visited.has(next)) {
            visited.add(next);
            parent.set(next, key);
            frontier.push(next);
          }
        }
      }
    }

    return null;
  }

  #rebuildGraph(): void {
    this.#vertices = new Map();
    this.#insertionCounter = 0;
    for (const [key, { value, before, after }] of this.#items) {
      this.#addToGraph(key, value, before, after);
    }
  }

  #replace(
    key: string,
    value: T,
    position?: DAGPosition,
    { repositionOnly }: { repositionOnly: boolean } = { repositionOnly: false }
  ): boolean {
    if (!this.has(key)) {
      return false;
    }

    const existingItem = this.#items.get(key);
    const oldValue = existingItem.value;
    const oldPosition = {
      before: existingItem.before,
      after: existingItem.after,
    };

    existingItem.value = value;

    if (position) {
      existingItem.before = position.before;
      existingItem.after = position.after;
    }

    this.#dirty = true;

    try {
      this.#rebuildGraph();
    } catch (e) {
      existingItem.value = oldValue;
      existingItem.before = oldPosition.before;
      existingItem.after = oldPosition.after;
      this.#rebuildGraph();
      throw e;
    }

    if (repositionOnly) {
      this.#onRepositionItem?.(key, position, oldPosition);
    } else {
      this.#onReplaceItem?.(key, value, oldValue, position, oldPosition);
    }

    return true;
  }

  /* Sorting */

  /**
   * Locality-preserving topological sort.
   *
   * Every vertex gets a placement rank, and the output is the topological
   * order closest to rank order: Kahn's algorithm always emits the
   * lowest-ranked ready vertex, so the result deviates from rank order
   * only where an edge contradicts it, and only for the vertices that
   * edge touches. The output is always a valid topological order.
   *
   * A rank is a path of `(side, insertionIdx)` steps rooted at an
   * unanchored vertex. Each vertex anchors to at most ONE key from its
   * applied position — the anchor decides where the vertex prefers to
   * sit, while every declared key remains a hard ordering edge:
   *
   * - `after: X` extends X's rank on the after side: the item sorts
   *   immediately after X (and after X's whole after-group, in insertion
   *   order), before anything unrelated to X.
   * - `before: X` extends X's rank on the before side: the item sorts
   *   immediately before X, again in insertion order within the group.
   * - With both `before` and `after`, the `after` anchor wins: the item
   *   hugs the item it follows.
   * - With multiple keys on one side, `after` anchors to the
   *   highest-ranked key and `before` to the lowest-ranked one — the
   *   nearest end of the window the constraints allow.
   * - Anchors never added to the DAG are ignored (an item constrained
   *   only relative to absent keys ranks by its own insertion index, and
   *   an absent key itself sorts past every real item, so anything
   *   `after` it lands at the end). Mutually recursive anchor references
   *   (e.g. `x after a` + `a before x`) break the loop at the vertex
   *   reached last, which then ranks by insertion index.
   */
  #sort(): string[] {
    const vertices = this.#vertices;
    const size = vertices.size;
    if (size === 0) {
      return [];
    }

    const sortedKeys = this.#keysInRankOrder();
    const ordinals = new Map<string, number>();
    for (let i = 0; i < sortedKeys.length; i++) {
      ordinals.set(sortedKeys[i], i);
    }

    const inDegree = new Map<string, number>();
    const ready = new MinHeap();
    for (const [key, v] of vertices) {
      inDegree.set(key, v.inEdges.size);
      if (v.inEdges.size === 0) {
        ready.push(ordinals.get(key));
      }
    }

    const result: string[] = [];
    while (ready.size > 0) {
      const key = sortedKeys[ready.pop()];
      result.push(key);

      for (const succKey of vertices.get(key).outEdges) {
        const d = inDegree.get(succKey) - 1;
        inDegree.set(succKey, d);
        if (d === 0) {
          ready.push(ordinals.get(succKey));
        }
      }
    }

    if (result.length !== size) {
      const remaining: string[] = [];
      for (const [key, deg] of inDegree) {
        if (deg > 0) {
          remaining.push(key);
        }
      }
      throw new DAGCycleError(
        "cycle detected among: " + JSON.stringify(remaining)
      );
    }

    return result;
  }

  #keysInRankOrder(): string[] {
    const ranks = this.#computeRanks();
    const keys = [...this.#vertices.keys()];
    keys.sort((a, b) => compareRanks(ranks.get(a), ranks.get(b)));
    return keys;
  }

  /**
   * Computes the placement rank of every vertex (see the sort method's
   * doc for the rank semantics).
   * Memoized per call; anchor chains are followed recursively with an
   * in-progress guard so mutually recursive anchor references terminate.
   */
  #computeRanks(): Map<string, number[]> {
    const ranks = new Map<string, number[]>();
    const inProgress = new Set<string>();

    const selectAnchor = (
      refs: string | string[] | undefined,
      latest: boolean
    ): string | null => {
      if (!refs) {
        return null;
      }

      let best: string | null = null;
      let bestRank: number[] | null = null;

      for (const ref of makeArray(refs)) {
        const anchor = this.#vertices.get(ref);
        if (!anchor || anchor.insertionIdx === -1 || inProgress.has(ref)) {
          continue;
        }

        const anchorRank = rankOf(ref);
        if (
          best === null ||
          (latest
            ? compareRanks(anchorRank, bestRank) > 0
            : compareRanks(anchorRank, bestRank) < 0)
        ) {
          best = ref;
          bestRank = anchorRank;
        }
      }

      return best;
    };

    const rankOf = (key: string): number[] => {
      let rank = ranks.get(key);
      if (rank !== undefined) {
        return rank;
      }

      const v = this.#vertices.get(key);
      // Placeholder vertices (referenced but never added) sort past every
      // real insertion index.
      const idx = v.insertionIdx === -1 ? Infinity : v.insertionIdx;

      inProgress.add(key);

      const afterAnchor = selectAnchor(v.appliedAfter, true);
      if (afterAnchor !== null) {
        rank = [...rankOf(afterAnchor), AFTER_ANCHOR, idx];
      } else {
        const beforeAnchor = selectAnchor(v.appliedBefore, false);
        rank =
          beforeAnchor !== null
            ? [...rankOf(beforeAnchor), BEFORE_ANCHOR, idx]
            : [idx];
      }

      inProgress.delete(key);
      ranks.set(key, rank);
      return rank;
    };

    for (const key of this.#vertices.keys()) {
      rankOf(key);
    }

    return ranks;
  }
}
