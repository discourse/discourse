import RESTAdapter from "discourse/adapters/rest";

export default class TagSettingsAdapter extends RESTAdapter {
  pathFor(store, type, id) {
    return `/tag/${id}/settings.json`;
  }
}
