import RestAdapter from "discourse/adapters/rest";

export default class Adapter extends RestAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/plugins/discourse-ai/";
  }

  pathFor(store, type, findArgs) {
    // Preserve the hyphenated route instead of the base adapter's underscore conversion.
    const path =
      this.basePath(store, type, findArgs) +
      store.pluralize(this.apiNameFor(type));
    return this.appendQueryParams(path, findArgs);
  }

  apiNameFor() {
    return "ai-decision-model";
  }
}
