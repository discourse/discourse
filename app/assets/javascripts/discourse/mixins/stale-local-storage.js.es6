import StaleResult from 'discourse/lib/stale-result';
import { hashString } from 'discourse/lib/hash';

// Mix this in to an adapter to provide stale caching in our key value store
export default {
  storageKey(type, findArgs) {
    const hashedArgs = Math.abs(hashString(JSON.stringify(findArgs)));
    return `${type}_${hashedArgs}`;
  },

  findStale(store, type, findArgs, opts) {
    const staleResult = new StaleResult();
    const key = (opts && opts.storageKey) || this.storageKey(type, findArgs);
    try {
      const stored = this.keyValueStore.getItem(key);
      if (stored) {
        const parsed = JSON.parse(stored);
        staleResult.setResults(parsed);
      }
    } catch(e) {
      // JSON parsing error
    }
    return staleResult;
  },

  find(store, type, findArgs, opts) {
    const key = (opts && opts.storageKey) || this.storageKey(type, findArgs);

    return this._super(store, type, findArgs).then((results) => {
      this.keyValueStore.setItem(key, JSON.stringify(results));
      return results;
    });
  }
};
