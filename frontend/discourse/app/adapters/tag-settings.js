import RESTAdapter from "discourse/adapters/rest";

export default class TagSettingsAdapter extends RESTAdapter {
  pathFor(store, type, findArgs) {
    // findArgs is "slug/id" format
    return `/tag/${findArgs}/settings.json`;
  }
}
