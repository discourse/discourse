import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  jsonMode: true,

  pathFor(store, type, id) {
    return `/review/${id}/explain.json`;
  }
});
