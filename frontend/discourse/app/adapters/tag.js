import RESTAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export default class TagAdapter extends RESTAdapter {
  pathFor(store, type, tagName) {
    return tagName ? `/tag/${tagName}` : `/tags`;
  }

  // the primaryKey is id,
  // but since tag routes use the tag name in the URL path, we override here
  destroyRecord(store, type, record) {
    return ajax(this.pathFor(store, type, record.get("name")), {
      type: "DELETE",
    });
  }
}
