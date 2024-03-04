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
   * Adds a key/value pair to the map. Can optionally specify before/after position requirements.
   *
   * @param {string} key The key of the item to be added. Can be referenced by other member's postition parameters.
   * @param {any} value
   * @param {Object} position
   * @param {string | string[]} position.before A key or array of keys of items which should appear before this one.
   * @param {string | string[]} position.after A key or array of keys of items which should appear after this one.
   */
  add(key, value, position) {
    position ||= this.#defaultPositionForKey(key);
    const { before, after } = position;
    this.#rawData.set(key, {
      value,
      before,
      after,
    });
    this.#dag.add(key, value, before, after);
  }

  /**
   * Remove an item from the map by key. no-op if the key does not exist.
   *
   * @param {string} key The key of the item to be removed.
   */
  delete(key) {
    this.#rawData.delete(key);
    this.#refreshDAG();
  }

  /**
   * Change the positioning rules of an existing item in the map. Will replace all existing rules. No-op if the key does not exist.
   *
   * @param {string} key
   * @param {string | string[]} position.before A key or array of keys of items which should appear before this one.
   * @param {string | string[]} position.after A key or array of keys of items which should appear after this one.
   */
  reposition(key, { before, after }) {
    const node = this.#rawData.get(key);
    if (node) {
      node.before = before;
      node.after = after;
    }
    this.#refreshDAG();
  }

  /**
   * Check whether an item exists in the map.
   * @param {string} key
   * @returns {boolean}
   *
   */
  has(key) {
    return this.#rawData.has(key);
  }

  /**
   * Return the resolved key/value pairs in the map. The order of the pairs is determined by the before/after rules.
   * @returns {Array<[key: string, value: any]}>} An array of key/value pairs.
   *
   */
  @bind
  resolve() {
    const result = [];
    this.#dag.each((key, value) => result.push({ key, value }));
    return result;
  }

  /**
   * DAGMap doesn't support removing or modifying keys, so we
   * need to completely recreate it from the raw data
   */
  #refreshDAG() {
    const newDAG = new DAGMap();
    for (const [key, { value, before, after }] of this.#rawData) {
      newDAG.add(key, value, before, after);
    }
    this.#dag = newDAG;
  }
}
