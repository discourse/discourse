import RESTAdapter from "discourse/adapters/rest";

export default RESTAdapter.extend({
  jsonMode: true,

  basePath() {
    return "/admin/api/";
  },

  apiNameFor() {
    return "key";
  },
});
