import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  jsonMode: true,

  pathFor(store, type, id) {
    return `/pub/by-topic/${id}`;
  },
});
