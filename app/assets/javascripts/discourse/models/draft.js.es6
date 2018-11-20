import { ajax } from "discourse/lib/ajax";
const Draft = Discourse.Model.extend();

Draft.reopenClass({
  clear(key, sequence) {
    return ajax("/draft.json", {
      type: "DELETE",
      data: {
        draft_key: key,
        sequence: sequence
      }
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

  save(key, sequence, data) {
    data = typeof data === "string" ? data : JSON.stringify(data);
    return ajax("/draft.json", {
      type: "POST",
      data: {
        draft_key: key,
        data: data,
        sequence: sequence
      }
    });
  }
});

export default Draft;
