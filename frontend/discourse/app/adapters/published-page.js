import RestAdapter from "discourse/adapters/rest";

export default class PublishedPageAdapter extends RestAdapter {
  jsonMode = true;

  pathFor(store, type, id) {
    return `/pub/by-topic/${id}`;
  }
}
