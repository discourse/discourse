import StaleResult from 'discourse/lib/stale-result';
import { hashString } from 'discourse/lib/hash';

// Mix this in to an adapter to provide stale caching in localStorage
export default {
  storageKey(type, findArgs) {
    const hashedArgs = Math.abs(hashString(JSON.stringify(findArgs)));
    return `${type}_${hashedArgs}`;
  },

  findStale(store, type, findArgs) {
    const staleResult = new StaleResult();
    try {
      const stored = localStorage.getItem(this.storageKey(type, findArgs));
      if (stored) {
        const parsed = JSON.parse(stored);
        staleResult.setResults(parsed);
      }

    } catch(e) {
      // JSON parsing error
    }
    return staleResult;
  },

  find(store, type, findArgs) {
    return this._super(store, type, findArgs).then((results) => {
      localStorage.setItem(this.storageKey(type, findArgs), JSON.stringify(results));
      return results;
    });
  }
}
