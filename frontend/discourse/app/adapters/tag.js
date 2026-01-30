import RESTAdapter, { Result } from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export default class TagAdapter extends RESTAdapter {
  pathFor(store, type, findArgs) {
    return findArgs ? `/tag/${findArgs}.json` : `/tags.json`;
  }

  update(store, type, id, attrs) {
    return ajax(
      `/tag/${attrs.slug}/${id}.json`,
      this.getPayload("PUT", { tag: attrs })
    ).then((json) => new Result(json.tag, json));
  }

  destroyRecord(store, type, record) {
    return ajax(`/tag/${record.get("slug")}/${record.get("id")}.json`, {
      type: "DELETE",
    });
  }
}
