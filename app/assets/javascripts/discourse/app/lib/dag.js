import DAGMap from "dag-map";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";

export default class DAG {
  /**
   * Creates a new DAG instance from an iterable of entries.
   *
   * @param {Iterable<[string, any, Object?]>} entriesLike - An iterable of key-value-position tuples to initialize the DAG.
   * @param {Object} [opts] - Optional configuration object.
   * @param {Object} [opts.defaultPosition] - Default positioning rules for new items.
   * @param {boolean} [opts.throwErrorOnCycle=true] - Flag indicating whether to throw an error when a cycle is detected. Default is true. When false, the default position will be used instead.
   * @param {string|string[]} [opts.defaultPosition.before] - A key or array of keys of items which should appear before this one.
   * @param {string|string[]} [opts.defaultPosition.after] - A key or array of keys of items which should appear after this one.
   * @param {(key: string, value: any, position: {before?: string|string[], after?: string|string[]}) => void} [opts.onAddItem] - Callback function to be called when an item is added.
   * @param {(key: string) => void} [opts.onDeleteItem] - Callback function to be called when an item is removed.
   * @param {(key: string, newValue: any, oldValue: any, newPosition: {before?: string|string[], after?: string|string[]}, oldPosition: {before?: string|string[], after?: string|string[]}) => void} [opts.onReplaceItem] - Callback function to be called when an item is replaced.
   * @param {(key: string, newPosition: {before?: string|string[], after?: string|string[]}, oldPosition: {before?: string|string[], after?: string|string[]}) => void} [opts.onRepositionItem] - Callback function to be called when an item is repositioned.
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

  #rawData = new Map();
  #dag = new DAGMap();

  /**
   * Creates a new Directed Acyclic Graph (DAG) instance.
   *
   * @param {Object} [opts] - Optional configuration object.
   * @param {Object} [opts.defaultPosition] - Default positioning rules for new items.
   * @param {boolean} [opts.throwErrorOnCycle=true] - Flag indicating whether to throw an error when a cycle is detected. When false, the default position will be used instead.
   * @param {string|string[]} [opts.defaultPosition.before] - A key or array of keys of items which should appear before this one.
   * @param {string|string[]} [opts.defaultPosition.after] - A key or array of keys of items which should appear after this one.
   * @param {(key: string, value: any, position: {before?: string|string[], after?: string|string[]}) => void} [opts.onAddItem] - Callback function to be called when an item is added.
   * @param {(key: string) => void} [opts.onDeleteItem] - Callback function to be called when an item is removed.
   * @param {(key: string, newValue: any, oldValue: any, newPosition: {before?: string|string[], after?: string|string[]}, oldPosition: {before?: string|string[], after?: string|string[]}) => void} [opts.onReplaceItem] - Callback function to be called when an item is replaced.
   * @param {(key: string, newPosition: {before?: string|string[], after?: string|string[]}, oldPosition: {before?: string|string[], after?: string|string[]}) => void} [opts.onRepositionItem] - Callback function to be called when an item is repositioned.
   */
  constructor(opts) {
    // allows for custom default positioning of new items added to the DAG, eg
    // new DAG({ defaultPosition: { before: "foo", after: "bar" } });
    this.#defaultPosition = opts?.defaultPosition || {};
    this.#throwErrorOnCycle = opts?.throwErrorOnCycle ?? true;

    this.#onAddItem = opts?.onAddItem;
    this.#onDeleteItem = opts?.onDeleteItem;
    this.#onReplaceItem = opts?.onReplaceItem;
    this.#onRepositionItem = opts?.onRepositionItem;
  }

  /**
   * Returns the default position for a given key, excluding the key itself from the before/after arrays.
   *
   * @param {string} key - The key to get the default position for.
   * @returns {Object} The default position object.
   * @private
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
   * Adds a key/value pair to the DAG map. Can optionally specify before/after position requirements.
   *
   * @param {string} key - The key of the item to be added. Can be referenced by other member's position parameters.
   * @param {any} value - The value of the item to be added.
   * @param {Object} [position] - The position object specifying before/after requirements.
   * @param {string|string[]} [position.before] - A key or array of keys of items which should appear before this one.
   * @param {string|string[]} [position.after] - A key or array of keys of items which should appear after this one.
   * @returns {boolean} True if the item was added, false if the key already exists.
   */
  add(key, value, position) {
    if (this.has(key)) {
      return false;
    }

    position ||= this.#defaultPositionForKey(key);
    const { before, after } = position;
    this.#rawData.set(key, {
      value,
      before,
      after,
    });

    this.#addHandlingCycles(this.#dag, key, value, before, after);
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
    const deleted = this.#rawData.delete(key);
    this.#refreshDAG();

    if (deleted) {
      this.#onDeleteItem?.(key);
    }

    return deleted;
  }

  /**
   * Replace an existing item in the map.
   *
   * @param {string} key - The key of the item to be replaced.
   * @param {any} value - The new value of the item.
   * @param {Object} position - The new position object specifying before/after requirements.
   * @param {string|string[]} [position.before] - A key or array of keys of items which should appear before this one.
   * @param {string|string[]} [position.after] - A key or array of keys of items which should appear after this one.
   * @returns {boolean} True if the item was replaced, false otherwise.
   */
  replace(key, value, position) {
    return this.#replace(key, value, position);
  }

  /**
   * Change the positioning rules of an existing item in the map. Will replace all existing rules.
   *
   * @param {string} key - The key of the item to reposition.
   * @param {Object} position - The new position object specifying before/after requirements.
   * @param {string|string[]} [position.before] - A key or array of keys of items which should appear before this one.
   * @param {string|string[]} [position.after] - A key or array of keys of items which should appear after this one.
   * @returns {boolean} True if the item was repositioned, false otherwise.
   */
  reposition(key, position) {
    if (!this.has(key) || !position) {
      return false;
    }

    const { value } = this.#rawData.get(key);

    return this.#replace(key, value, position, { repositionOnly: true });
  }

  /**
   * Check whether an item exists in the map.
   *
   * @param {string} key - The key to check for existence.
   * @returns {boolean} True if the item exists, false otherwise.
   */
  has(key) {
    return this.#rawData.has(key);
  }

  /**
   * Returns an array of entries in the DAG. Each entry is a tuple containing the key, value, and position object.
   *
   * @returns {Array<[string, any, {before?: string|string[], after?: string|string[]}]>} An array of key-value-position tuples.
   */
  entries() {
    return Array.from(this.#rawData.entries()).map(
      ([key, { value, before, after }]) => [key, value, { before, after }]
    );
  }

  /**
   * Return the resolved key/value pairs in the map. The order of the pairs is determined by the before/after rules.
   *
   * @returns {Array<{key: string, value: any, position: {before?: string|string[], after?: string|string[]}}>} An array of key/value/position objects.
   */
  @bind
  resolve() {
    const result = [];
    this.#dag.each((key, value) => {
      // We need to filter keys that do not exist in the rawData because the DAGMap will insert a vertex for
      // dependencies, for example if an item has a "before: search" dependency, the "search" vertex will be included
      // even if it was explicitly excluded from the raw data.
      if (this.has(key)) {
        const { before, after } = this.#rawData.get(key);
        result.push({ key, value, position: { before, after } });
      }
    });
    return result;
  }

  /**
   * Adds a key/value pair to the DAG map while handling potential cycles.
   *
   * @param {DAGMap} dag - The DAG map instance to add the key/value pair to.
   * @param {string} key - The key of the item to be added.
   * @param {any} value - The value of the item to be added.
   * @param {string|string[]} [before] - A key or array of keys of items which should appear before this one.
   * @param {string|string[]} [after] - A key or array of keys of items which should appear after this one.
   * @throws {Error} Throws an error if a cycle is detected and `throwErrorOnCycle` is true.
   * @private
   */
  #addHandlingCycles(dag, key, value, before, after) {
    if (this.#throwErrorOnCycle) {
      dag.add(key, value, before, after);
    } else {
      try {
        dag.add(key, value, before, after);
      } catch (e) {
        if (e.message.match(/cycle/i)) {
          const { before: newBefore, after: newAfter } =
            this.#defaultPositionForKey(key);

          // if even the default position causes a cycle, an error will be thrown
          dag.add(key, value, newBefore, newAfter);
        }
      }
    }
  }

  /**
   * Replace an existing item in the map.
   *
   * @param {string} key - The key of the item to be replaced.
   * @param {any} value - The new value of the item.
   * @param {Object} position - The new position object specifying before/after requirements.
   * @param {string|string[]} [position.before] - A key or array of keys of items which should appear before this one.
   * @param {string|string[]} [position.after] - A key or array of keys of items which should appear after this one.
   * @param {Object} [options] - Additional options.
   * @param {boolean} [options.repositionOnly=false] - Whether the replacement is for repositioning only.
   * @returns {boolean} True if the item was replaced, false otherwise.
   * @private
   */
  #replace(
    key,
    value,
    position,
    { repositionOnly } = { repositionOnly: false }
  ) {
    if (!this.has(key)) {
      return false;
    }

    const existingItem = this.#rawData.get(key);
    const oldValue = existingItem.value;
    const oldPosition = {
      before: existingItem.before,
      after: existingItem.after,
    };

    // mutating the existing item keeps the position in the map in case before/after weren't explicitly set
    existingItem.value = value;

    if (position) {
      existingItem.before = position.before;
      existingItem.after = position.after;
    }

    this.#refreshDAG();

    if (repositionOnly) {
      this.#onRepositionItem?.(key, position, oldPosition);
    } else {
      this.#onReplaceItem?.(key, value, oldValue, position, oldPosition);
    }

    return true;
  }

  /**
   * Refreshes the DAG by recreating it from the raw data.
   *
   * @private
   */
  #refreshDAG() {
    const newDAG = new DAGMap();
    for (const [key, { value, before, after }] of this.#rawData) {
      this.#addHandlingCycles(newDAG, key, value, before, after);
    }
    this.#dag = newDAG;
  }
}
