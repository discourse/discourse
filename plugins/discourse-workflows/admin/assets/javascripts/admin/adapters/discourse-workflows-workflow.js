import RestAdapter from "discourse/adapters/rest";

export default class DiscourseWorkflowsWorkflowAdapter extends RestAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/plugins/discourse-workflows/";
  }

  pathFor(store, type, findArgs) {
    return super.pathFor(store, type, findArgs) + ".json";
  }

  apiNameFor() {
    return "workflow";
  }
}
