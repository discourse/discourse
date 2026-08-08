import { underscore } from "@ember/string";
import RestAdapter from "discourse/adapters/rest";

export default class DiscourseWorkflowsWorkflowAdapter extends RestAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/plugins/discourse-workflows/";
  }

  pathFor(store, type, findArgs) {
    const path =
      this.basePath() + underscore(store.pluralize(this.apiNameFor()));
    const result = this.appendQueryParams(path, findArgs, ".json");
    return result === path ? `${path}.json` : result;
  }

  apiNameFor() {
    return "workflow";
  }
}
