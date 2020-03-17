import RESTAdapter from "discourse/adapters/rest";

export default RESTAdapter.extend({
  basePath() {
    return "/admin/api/";
  },

  apiNameFor() {
    return "key";
  }
});
