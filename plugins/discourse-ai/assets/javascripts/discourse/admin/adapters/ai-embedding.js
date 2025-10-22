import RestAdapter from "discourse/adapters/rest";

export default class Adapter extends RestAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/plugins/discourse-ai/";
  }

  pathFor(store, type, findArgs) {
    // removes underscores which are implemented in base
    let path =
      this.basePath(store, type, findArgs) +
      store.pluralize(this.apiNameFor(type));
    return this.appendQueryParams(path, findArgs);
  }

  apiNameFor() {
    return "ai-embedding";
  }
}
