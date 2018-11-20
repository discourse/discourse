import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  pathFor() {
    return "/admin/customize/embedding";
  }
});
