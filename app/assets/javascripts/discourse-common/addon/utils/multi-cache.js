// Used for Category.asyncFindByIds
//
// It's a cache that handles multiple lookups at a time.
export class MultiCache {
  constructor(cb) {
    this.cb = cb;
    this.values = new Map();
    this.fetchTimes = [];
  }

  reset() {
    this.values = new Map();
    this.fetchTimes = [];
  }

  hadTooManyCalls() {
    const [t1, t2] = this.fetchTimes;
    return t1 && t2 && t2 - t1 < 1000;
  }

  async fetch(ids) {
    this.fetchTimes = [this.fetchTimes[this.fetchTimes.length - 1], new Date()];

    const notFound = [];
    ids = ids.uniq();

    for (const id of ids) {
      if (!this.values.has(id)) {
        notFound.push(id);
      }
    }

    if (notFound.length !== 0) {
      const request = this.cb(notFound);

      for (const id of notFound) {
        this.values.set(id, request);
      }

      request.catch(() => {
        for (const id of notFound) {
          this.values.delete(id);
        }
      });
    }

    const response = new Map();

    for (const id of ids) {
      response.set(id, (await this.values.get(id)).get(id));
    }

    return response;
  }
}
