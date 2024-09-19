import DAGMap from "dag-map";
import { bind } from "discourse-common/utils/decorators";

function ensureArray(val) {
  return Array.isArray(val) ? val : [val];
}

export default class DAG {
  #defaultPosition;
  #rawData = new Map();
  #dag = new DAGMap();

  constructor(args) {
    // allows for custom default positioning of new items added to the DAG, eg
    // new DAG({ defaultPosition: { before: "foo", after: "bar" } });
    this.#defaultPosition = args?.defaultPosition || {};
  }

  /**
   * Returns the default position for a given key, excluding the key itself from the before/after arrays.
   *
   * @param {string} key - The key to get the default position for.
   * @returns {Object} The default position object.
   */
  #defaultPositionForKey(key) {
    const pos = { ...this.#defaultPosition };
    if (ensureArray(pos.before).includes(key)) {
      delete pos.before;
    }
    if (ensureArray(pos.after).includes(key)) {
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
    this.#dag.add(key, value, before, after);

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
    if (!this.has(key)) {
      return false;
    }

    const existingItem = this.#rawData.get(key);
    this.#rawData.set(key, { ...existingItem, ...position, value });
    this.#refreshDAG();

    return true;
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
    if (!this.has(key)) {
      return false;
    }

    const { value } = this.#rawData.get(key);

    return this.replace(key, value, position);
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
   * Return the resolved key/value pairs in the map. The order of the pairs is determined by the before/after rules.
   *
   * @returns {Array<{key: string, value: any}>} An array of key/value pairs.
   */
  @bind
  resolve() {
    const result = [];
    this.#dag.each((key, value) => {
      // We need to filter keys that do not exist in the rawData because the DAGMap will insert a vertex for
      // dependencies, for example if an item has a "before: search" dependency, the "search" vertex will be included
      // even if it was explicitly excluded from the raw data.
      if (this.has(key)) {
        result.push({ key, value });
      }
    });
    return result;
  }

  /**
   * Refreshes the DAG by recreating it from the raw data.
   *
   * @private
   */
  #refreshDAG() {
    const newDAG = new DAGMap();
    for (const [key, { value, before, after }] of this.#rawData) {
      newDAG.add(key, value, before, after);
    }
    this.#dag = newDAG;
  }
}
