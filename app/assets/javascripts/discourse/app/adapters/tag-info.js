import RESTAdapter from "discourse/adapters/rest";

export default class TagInfoAdapter extends RESTAdapter {
  pathFor(store, type, id) {
    return "/tag/" + id + "/info";
  }
}
