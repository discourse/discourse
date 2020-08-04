import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  pathFor() {
    return "/review/settings";
  }
});
