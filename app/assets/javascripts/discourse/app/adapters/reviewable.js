import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  jsonMode: true,

  pathFor(store, type, findArgs) {
    return this.appendQueryParams("/review", findArgs);
  }
});
