// @ts-check
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";

/**
 * Module-level cache for sort results. Keyed by a content fingerprint
 * (keys + before/after constraints), stores the sorted key order.
 * Different DAG instances with the same structure share the cached
 * order, which matters for hot paths like the post menu where the
 * same button set is resolved per post.
 */
const sortCache = new Map();
const SORT_CACHE_MAX = 50;

const WAITING = 0;
const READY_QUEUE = 1;
const READY_STACK = 2;
const PLACED = 3;

function normalizePosition(pos) {
  if (!pos) {
    return "";
  }
  if (typeof pos === "string") {
    return pos;
  }
  return pos.join("\x1F");
}

/**
 * @typedef {Object} DAGPosition
 * @property {string|string[]} [before] - A key or array of keys of items which should appear before this one.
 * @property {string|string[]} [after] - A key or array of keys of items which should appear after this one.
 */

/**
 * @typedef {Object} DAGOptions
 * @property {DAGPosition} [defaultPosition] - Default positioning rules for new items.
 * @property {boolean} [throwErrorOnCycle=true] - Whether to throw an error when a cycle is detected. When false, the default position will be used instead.
 * @property {(key: string, value: any, position: DAGPosition) => void} [onAddItem] - Called when an item is added.
 * @property {(key: string) => void} [onDeleteItem] - Called when an item is removed.
 * @property {(key: string, newValue: any, oldValue: any, newPosition: DAGPosition, oldPosition: DAGPosition) => void} [onReplaceItem] - Called when an item is replaced.
 * @property {(key: string, newPosition: DAGPosition, oldPosition: DAGPosition) => void} [onRepositionItem] - Called when an item is repositioned.
 */

export default class DAG {
  /**
   * Creates a new DAG instance from an iterable of entries.
   *
   * @param {Iterable<[string, any, DAGPosition?]>} entriesLike - An iterable of key-value-position tuples to initialize the DAG.
   * @param {DAGOptions} [opts] - Optional configuration object.
   * @returns {DAG} A new DAG instance.
   */
  static from(entriesLike, opts) {
    const dag = new this(opts);

    for (const [key, value, position] of entriesLike) {
      dag.add(key, value, position);
    }

    return dag;
  }

  #defaultPosition;
  #onAddItem;
  #onDeleteItem;
  #onReplaceItem;
  #onRepositionItem;
  #throwErrorOnCycle;

  #items = new Map();
  #vertices = new Map();
  #insertionCounter = 0;
  #dirty = true;
  #cachedResolve = null;

  /**
   * Creates a new Directed Acyclic Graph (DAG) instance.
   *
   * @param {DAGOptions} [opts] - Optional configuration object.
   */
  constructor(opts) {
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
   * @param {string} key - The key of the item to be added. Can be referenced by other member's position parameters.
   * @param {any} value - The value of the item to be added.
   * @param {DAGPosition} [position] - The position object specifying before/after requirements.
   * @returns {boolean} True if the item was added, false if the key already exists.
   */
  add(key, value, position) {
    if (this.has(key)) {
      return false;
    }

    position ||= this.#defaultPositionForKey(key);
    const { before, after } = position;
    this.#items.set(key, { value, before, after });
    this.#dirty = true;

    this.#addToGraph(key, value, before, after);
    this.#onAddItem?.(key, value, position);

    return true;
  }

  /**
   * Remove an item from the map by key.
   *
   * @param {string} key - The key of the item to be removed.
   * @returns {boolean} True if the item was deleted, false otherwise.
   */
  delete(key) {
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
   * @param {string} key - The key of the item to be replaced.
   * @param {any} value - The new value of the item.
   * @param {DAGPosition} [position] - The new position constraints. If omitted, the existing position is preserved.
   * @returns {boolean} True if the item was replaced, false otherwise.
   */
  replace(key, value, position) {
    return this.#replace(key, value, position);
  }

  /**
   * Change the positioning rules of an existing item in the map. Will replace all existing rules.
   *
   * @param {string} key - The key of the item to reposition.
   * @param {DAGPosition} position - The new position constraints. Replaces all existing rules.
   * @returns {boolean} True if the item was repositioned, false otherwise.
   */
  reposition(key, position) {
    if (!this.has(key) || !position) {
      return false;
    }

    const { value } = this.#items.get(key);

    return this.#replace(key, value, position, { repositionOnly: true });
  }

  /**
   * Check whether an item exists in the map.
   *
   * @param {string} key - The key to check for existence.
   * @returns {boolean} True if the item exists, false otherwise.
   */
  has(key) {
    return this.#items.has(key);
  }

  /**
   * Returns an array of entries in the DAG. Each entry is a tuple containing the key, value, and position object.
   *
   * @returns {Array<[string, any, DAGPosition]>} An array of key-value-position tuples.
   */
  entries() {
    return Array.from(this.#items.entries()).map(
      ([key, { value, before, after }]) => [key, value, { before, after }]
    );
  }

  /**
   * Return the resolved key/value pairs in the map. The order of the
   * pairs is determined by the before/after rules using a
   * locality-preserving topological sort.
   *
   * Results are cached at two levels:
   * 1. Instance level: repeated resolve() calls on an unmutated DAG
   *    return the same result (helps header icons/buttons singletons).
   * 2. Module level: different DAG instances with the same keys and
   *    constraints share the cached sort order (helps post menu where
   *    a new DAG is created per post with the same button set).
   *
   * @returns {Array<{key: string, value: any, position: DAGPosition}>} An array of key/value/position objects.
   */
  @bind
  resolve() {
    if (!this.#dirty && this.#cachedResolve) {
      return this.#cachedResolve;
    }

    const sortedKeys = this.#resolveKeyOrder();
    const result = [];

    for (let i = 0; i < sortedKeys.length; i++) {
      const key = sortedKeys[i];
      if (this.has(key)) {
        const { value, before, after } = this.#items.get(key);
        result.push({ key, value, position: { before, after } });
      }
    }

    this.#dirty = false;
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
   * @param {string} key - The key to compute the default position for.
   * @returns {Object} The default position with self-references stripped.
   */
  #defaultPositionForKey(key) {
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
   * @param {string} key - The vertex key.
   * @returns {Object} The vertex object.
   */
  #getOrCreateVertex(key) {
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
   * @param {string} key - The vertex key.
   * @param {any} value - The vertex value.
   * @param {string|string[]} [before] - Key(s) this vertex must appear before.
   * @param {string|string[]} [after] - Key(s) this vertex must appear after.
   */
  #addToGraph(key, value, before, after) {
    if (this.#throwErrorOnCycle) {
      this.#addVertexAndEdges(key, value, before, after);
    } else {
      try {
        this.#addVertexAndEdges(key, value, before, after);
      } catch (e) {
        if (e.message.match(/cycle/i)) {
          const { before: newBefore, after: newAfter } =
            this.#defaultPositionForKey(key);
          try {
            this.#addVertexAndEdges(key, value, newBefore, newAfter);
          } catch (e2) {
            if (!e2.message?.match(/cycle/i)) {
              throw e2;
            }
            // Both the requested and default positions create a cycle.
            // The vertex exists but has no constraint edges.
          }
        }
      }
    }
  }

  #addVertexAndEdges(key, value, before, after) {
    const v = this.#getOrCreateVertex(key);
    v.val = value;
    if (v.insertionIdx === -1) {
      v.insertionIdx = this.#insertionCounter++;
    }

    // Track edges added during this call as [fromKey, toKey] pairs
    // so they can be rolled back if a later constraint creates a cycle.
    const added = [];

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
  }

  #addEdge(from, to) {
    if (from.key === to.key) {
      throw new Error("cycle detected: " + to.key + " <- " + to.key);
    }

    if (from.outEdges.has(to.key)) {
      return false;
    }

    if (to.outEdges.size > 0) {
      const path = this.#findCyclePath(to, from.key);
      if (path !== null) {
        throw new Error("cycle detected: " + path);
      }
    }

    from.outEdges.add(to.key);
    to.inEdges.add(from.key);
    return true;
  }

  #findCyclePath(start, targetKey) {
    if (start.outEdges.has(targetKey)) {
      return targetKey + " <- " + start.key + " <- " + targetKey;
    }

    const visited = new Set([start.key]);
    const parent = new Map();
    const frontier = [];

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
        let cur = targetKey;
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

  #rebuildGraph() {
    this.#vertices = new Map();
    this.#insertionCounter = 0;
    for (const [key, { value, before, after }] of this.#items) {
      this.#addToGraph(key, value, before, after);
    }
  }

  #replace(
    key,
    value,
    position,
    { repositionOnly } = { repositionOnly: false }
  ) {
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
   * Returns the sorted key order, using the module-level content cache
   * when possible. The cache is keyed by a fingerprint of the items
   * and their constraints (values are excluded since they don't affect
   * sort order).
   */
  #resolveKeyOrder() {
    const fingerprint = this.#contentFingerprint();
    const cached = sortCache.get(fingerprint);
    if (cached) {
      sortCache.delete(fingerprint);
      sortCache.set(fingerprint, cached);
      return cached;
    }

    const sortedKeys = this.#sort();

    if (sortCache.size >= SORT_CACHE_MAX) {
      sortCache.delete(sortCache.keys().next().value);
    }
    sortCache.set(fingerprint, sortedKeys);

    return sortedKeys;
  }

  #contentFingerprint() {
    let fp = "";
    for (const [key, { before, after }] of this.#items) {
      fp +=
        key +
        "\0" +
        normalizePosition(before) +
        "\0" +
        normalizePosition(after) +
        "\n";
    }
    return fp;
  }

  /**
   * Locality-preserving topological sort using modified Kahn's algorithm.
   *
   * Two mechanisms keep constrained nodes close together:
   * - Successor boost: when a node is placed, its newly-ready successors
   *   go onto a stack so they're visited next.
   * - Sibling boost: when a successor isn't ready yet, its OTHER ready
   *   predecessors are pulled onto the stack so all predecessors are
   *   grouped together.
   */
  #sort() {
    const vertices = this.#vertices;
    const size = vertices.size;
    if (size === 0) {
      return [];
    }

    const inDegree = new Map();
    const state = new Map();

    for (const [key, v] of vertices) {
      inDegree.set(key, v.inEdges.size);
      state.set(key, v.inEdges.size === 0 ? READY_QUEUE : WAITING);
    }

    const queue = [];
    for (const [key, s] of state) {
      if (s === READY_QUEUE) {
        queue.push(key);
      }
    }
    queue.sort((a, b) => this.#compareKeys(a, b));

    const stack = [];
    const result = [];
    let queueIdx = 0;

    while (stack.length > 0 || queueIdx < queue.length) {
      let key;
      if (stack.length > 0) {
        key = stack.pop();
      } else {
        while (
          queueIdx < queue.length &&
          state.get(queue[queueIdx]) !== READY_QUEUE
        ) {
          queueIdx++;
        }
        if (queueIdx >= queue.length) {
          break;
        }
        key = queue[queueIdx++];
      }

      const v = vertices.get(key);
      state.set(key, PLACED);
      result.push(key);

      const ready = [];

      for (const succKey of v.outEdges) {
        const d = inDegree.get(succKey) - 1;
        inDegree.set(succKey, d);

        if (d === 0) {
          ready.push(succKey);
          state.set(succKey, READY_STACK);
        } else {
          /* Sibling boost: pull the successor's other ready predecessors
             onto the stack so all predecessors are grouped together. */
          const succ = vertices.get(succKey);
          for (const predKey of succ.inEdges) {
            if (state.get(predKey) === READY_QUEUE) {
              state.set(predKey, READY_STACK);
              ready.push(predKey);
            }
          }
        }
      }

      if (ready.length > 0) {
        if (ready.length > 1) {
          ready.sort((a, b) => this.#compareKeys(a, b));
        }
        for (let i = ready.length - 1; i >= 0; i--) {
          stack.push(ready[i]);
        }
      }
    }

    if (result.length !== size) {
      const remaining = [];
      for (const [key, deg] of inDegree) {
        if (deg > 0) {
          remaining.push(key);
        }
      }
      throw new Error("cycle detected among: " + JSON.stringify(remaining));
    }

    return result;
  }

  #compareKeys(a, b) {
    const va = this.#vertices.get(a);
    const vb = this.#vertices.get(b);

    const aHasOut = va.outEdges.size > 0 ? 0 : 1;
    const bHasOut = vb.outEdges.size > 0 ? 0 : 1;
    if (aHasOut !== bHasOut) {
      return aHasOut - bHasOut;
    }

    const idxA = va.insertionIdx === -1 ? 2147483647 : va.insertionIdx;
    const idxB = vb.insertionIdx === -1 ? 2147483647 : vb.insertionIdx;
    return idxA - idxB;
  }
}
