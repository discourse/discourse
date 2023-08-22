import RESTAdapter from "discourse/adapters/rest";

export default class extends RESTAdapter {
  pathFor(_store, _type, findArgs) {
    return this.appendQueryParams("/tags/list", findArgs);
  }
}
