import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class Draft extends EmberObject {
  static clear(key, sequence) {
    return ajax(`/drafts/${key}.json`, {
      type: "DELETE",
      data: { draft_key: key, sequence },
    });
  }

  static get(key) {
    return ajax(`/drafts/${key}.json`);
  }

  static getLocal(key, current) {
    // TODO: implement this
    return current;
  }

  static save(key, sequence, data, clientId, { forceSave = false } = {}) {
    data = typeof data === "string" ? data : JSON.stringify(data);
    return ajax("/drafts.json", {
      type: "POST",
      data: {
        draft_key: key,
        sequence,
        data,
        owner: clientId,
        force_save: forceSave,
      },
      ignoreUnsent: false,
    });
  }
}
