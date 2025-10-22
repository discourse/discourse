import RESTAdapter from "discourse/adapters/rest";

export default class TagAdapter extends RESTAdapter {
  pathFor(store, type, id) {
    return id ? `/tag/${id}` : `/tags`;
  }
}
