const Draft = Discourse.Model.extend();

Draft.reopenClass({

  clear(key, sequence) {
    return Discourse.ajax("/draft.json", {
      type: 'DELETE',
      data: {
        draft_key: key,
        sequence: sequence
      }
    });
  },

  get(key) {
    return Discourse.ajax('/draft.json', {
      data: { draft_key: key },
      dataType: 'json'
    });
  },

  getLocal(key, current) {
    // TODO: implement this
    return current;
  },

  save(key, sequence, data) {
    data = typeof data === "string" ? data : JSON.stringify(data);
    return Discourse.ajax("/draft.json", {
      type: 'POST',
      data: {
        draft_key: key,
        data: data,
        sequence: sequence
      }
    });
  }

});

export default Draft;
