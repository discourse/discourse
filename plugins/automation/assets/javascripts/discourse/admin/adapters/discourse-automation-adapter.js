import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  basePath() {
    return "/admin/plugins/discourse-automation/";
  },

  pathFor() {
    return this._super(...arguments).replace("_", "-") + ".json";
  },
});
