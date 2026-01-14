import Service from "@ember/service";

export default class MapCache extends Service {
  cache = {};

  get(key) {
    const cachedItem = this.cache[key];
    if (!cachedItem) {
      return null;
    }

    const { value, timestamp, ttl } = cachedItem;
    const now = Date.now();

    if (now - timestamp > ttl) {
      this.clear(key);
      return null;
    }

    return value;
  }

  set(key, value, ttl = 120000) {
    // expires after 2 min
    this.cache[key] = {
      value,
      timestamp: Date.now(),
      ttl,
    };
  }

  clear(key) {
    delete this.cache[key];
  }
}
