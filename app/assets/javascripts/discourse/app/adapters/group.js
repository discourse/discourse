import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  appendQueryParams(path, findArgs) {
    return this._super(path, findArgs, ".json");
  }
});
