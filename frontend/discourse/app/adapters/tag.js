import RESTAdapter from "discourse/adapters/rest";

export default class TagAdapter extends RESTAdapter {
  primaryKey = "name";

  pathFor(store, type, tagName) {
    return tagName ? `/tag/${tagName}` : `/tags`;
  }
}
