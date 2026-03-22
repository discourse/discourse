import RestAdapter from "discourse/adapters/rest";

export default class DiscourseWorkflowsWorkflowAdapter extends RestAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/plugins/discourse-workflows/";
  }

  apiNameFor() {
    return "workflow";
  }
}
