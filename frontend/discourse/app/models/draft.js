import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";

export default class Draft extends EmberObject {
  static clear(key, sequence) {
    return ajax(`/drafts/${key}.json`, {
      type: "DELETE",
      data: { draft_key: key, sequence },
    });
  }

  static bulkClear(drafts) {
    const draft_keys = drafts.map((d) => d.draft_key);
    const sequences = {};
    drafts.forEach((d) => {
      sequences[d.draft_key] = d.sequence;
    });

    return ajax("/drafts/bulk_destroy.json", {
      type: "DELETE",
      data: { draft_keys, sequences },
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

  static saveBeacon(key, sequence, data, clientId, csrfToken) {
    const formData = new FormData();
    formData.append("draft_key", key);
    formData.append("sequence", sequence);
    formData.append("data", JSON.stringify(data));
    formData.append("owner", clientId);
    formData.append("authenticity_token", csrfToken);
    navigator.sendBeacon(getURL("/drafts.json"), formData);
  }
}
