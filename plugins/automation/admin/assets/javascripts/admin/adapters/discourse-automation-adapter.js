import RestAdapter from "discourse/adapters/rest";

export default class Adapter extends RestAdapter {
  basePath() {
    return "/admin/plugins/automation/";
  }

  pathFor() {
    return super.pathFor(...arguments).replace("_", "-") + ".json";
  }
}
