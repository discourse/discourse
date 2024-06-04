import RESTAdapter from "discourse/adapters/rest";

export default class TagNotificationAdapter extends RESTAdapter {
  pathFor(store, type, id) {
    return "/tag/" + id + "/notifications";
  }
}
