import { ajax } from "discourse/lib/ajax";
import EmberObject from "@ember/object";

const Draft = EmberObject.extend();

Draft.reopenClass({
  clear(key, sequence) {
    return ajax("/draft.json", {
      type: "DELETE",
      data: { draft_key: key, sequence }
    });
  },

  get(key) {
    return ajax("/draft.json", {
      data: { draft_key: key },
      dataType: "json"
    });
  },

  getLocal(key, current) {
    // TODO: implement this
    return current;
  },

  save(key, sequence, data, clientId) {
    data = typeof data === "string" ? data : JSON.stringify(data);
    return ajax("/draft.json", {
      type: "POST",
      data: { draft_key: key, sequence, data, owner: clientId }
    });
  }
});

export default Draft;
