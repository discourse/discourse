import RESTAdapter from "discourse/adapters/rest";

export default class ListTagAdapter extends RESTAdapter {
  pathFor(_store, _type, findArgs) {
    return this.appendQueryParams("/tags/list", findArgs);
  }
}
