/**
 * A Map that holds weak references to its values, allowing them to be
 * garbage collected when no other references exist.
 *
 * Use cases:
 * - Caches that won't grow forever: cached values are automatically evicted
 *   when no longer referenced elsewhere, preventing memory leaks.
 * - Identity maps: ensures the same key always returns the same object instance
 *   while allowing unused entries to be garbage collected.
 * - Memoization: stores computed results that can be recalculated if evicted.
 *
 * This class provides the same API as the standard Map, but values may
 * disappear if they are garbage collected. Methods like `get()` and iterators
 * will return `undefined` or skip entries whose values have been collected.
 *
 * @template K - The key type.
 * @template {object} V - The value type. Must be an object since WeakRef
 *   only works with objects.
 */
class WeakValueMap {
  #map = new Map();
  #registry;

  constructor() {
    this.#registry = new FinalizationRegistry((key) => {
      const ref = this.#map.get(key);
      // Only delete if the ref is dead. A new value might have been set
      // for this key after the old value was garbage collected.
      if (ref && ref.deref() === undefined) {
        this.#map.delete(key);
      }
    });
  }

  /**
   * Scans the map and removes entries whose values have been garbage collected.
   *
   * This method serves as a backup cleanup mechanism in case the
   * FinalizationRegistry doesn't run promptly. It uses an early-exit
   * optimization: if the first SAMPLE_SIZE entries are all live, we assume
   * the registry is doing its job and skip the full scan. If any dead entry
   * is found in the sample, we continue scanning the entire map since dead
   * refs tend to cluster (e.g., after route transitions drop many models).
   */
  #sweep() {
    const SAMPLE_SIZE = 20;
    let checked = 0;
    let foundDead = false;

    for (const [key, ref] of this.#map) {
      const dead = ref.deref() === undefined;

      if (dead) {
        this.#map.delete(key);
        foundDead = true;
      }

      checked++;

      // Early exit: if first N entries are all live, assume registry is working
      if (!foundDead && checked >= SAMPLE_SIZE) {
        return;
      }
    }
  }

  /**
   * Returns the number of entries in the map.
   *
   * Note: This value may be inaccurate because it can include entries whose
   * values have been garbage collected but not yet cleaned up by the
   * FinalizationRegistry. For an accurate count, iterate over the map.
   *
   * @returns {number}
   */
  get size() {
    return this.#map.size;
  }

  /**
   * Gets the value associated with a key.
   *
   * @param {K} key - The key to look up.
   * @returns {V | undefined} The value, or undefined if the key doesn't exist
   *   or its value has been garbage collected.
   */
  get(key) {
    // ~1% chance to sweep on each get
    if (Math.random() < 0.01) {
      this.#sweep();
    }

    const ref = this.#map.get(key);
    if (ref) {
      const value = ref.deref();
      if (value !== undefined) {
        return value;
      }
      // Value was garbage collected, clean up the entry.
      this.#map.delete(key);
    }
    return undefined;
  }

  /**
   * Sets a value for a key.
   *
   * @param {K} key - The key to set.
   * @param {V} value - The value to associate with the key.
   * @returns {this} The map instance for chaining.
   */
  set(key, value) {
    const existingRef = this.#map.get(key);
    if (existingRef) {
      const oldValue = existingRef.deref();
      if (oldValue !== undefined) {
        this.#registry.unregister(oldValue);
      }
    }

    this.#map.set(key, new WeakRef(value));
    this.#registry.register(value, key, value);
    return this;
  }

  /**
   * Checks if a key exists and its value is still alive.
   *
   * @param {K} key - The key to check.
   * @returns {boolean} True if the key exists and its value hasn't been
   *   garbage collected.
   */
  has(key) {
    return this.get(key) !== undefined;
  }

  /**
   * Deletes an entry by key.
   *
   * @param {K} key - The key to delete.
   * @returns {boolean} True if an entry was deleted.
   */
  delete(key) {
    const ref = this.#map.get(key);
    if (ref) {
      const value = ref.deref();
      if (value !== undefined) {
        this.#registry.unregister(value);
      }
      this.#map.delete(key);
      return true;
    }
    return false;
  }

  /**
   * Removes all entries from the map.
   */
  clear() {
    for (const ref of this.#map.values()) {
      const value = ref.deref();
      if (value !== undefined) {
        this.#registry.unregister(value);
      }
    }
    this.#map.clear();
  }

  /**
   * Returns an iterator over the keys in the map. Keys whose values have
   * been garbage collected are skipped and cleaned up.
   *
   * @returns {Generator<K>}
   */
  *keys() {
    for (const [key, ref] of this.#map) {
      const value = ref.deref();
      if (value !== undefined) {
        yield key;
      } else {
        this.#map.delete(key);
      }
    }
  }

  /**
   * Returns an iterator over the values in the map. Entries whose values
   * have been garbage collected are skipped and cleaned up.
   *
   * @returns {Generator<V>}
   */
  *values() {
    for (const [key, ref] of this.#map) {
      const value = ref.deref();
      if (value !== undefined) {
        yield value;
      } else {
        this.#map.delete(key);
      }
    }
  }

  /**
   * Returns an iterator over [key, value] pairs in the map. Entries whose
   * values have been garbage collected are skipped and cleaned up.
   *
   * @returns {Generator<[K, V]>}
   */
  *entries() {
    for (const [key, ref] of this.#map) {
      const value = ref.deref();
      if (value !== undefined) {
        yield [key, value];
      } else {
        this.#map.delete(key);
      }
    }
  }

  /**
   * Executes a callback for each live entry in the map.
   *
   * @param {(value: V, key: K, map: WeakValueMap<K, V>) => void} callback -
   *   The function to execute for each entry.
   * @param {*} [thisArg] - Value to use as `this` when executing the callback.
   */
  forEach(callback, thisArg) {
    for (const [key, value] of this) {
      callback.call(thisArg, value, key, this);
    }
  }

  /**
   * Returns an iterator over [key, value] pairs, same as entries().
   *
   * @returns {Generator<[K, V]>}
   */
  [Symbol.iterator]() {
    return this.entries();
  }

  /**
   * Returns the string tag for the object, used by Object.prototype.toString().
   *
   * @returns {string}
   */
  get [Symbol.toStringTag]() {
    return "WeakValueMap";
  }
}

export default WeakValueMap;
