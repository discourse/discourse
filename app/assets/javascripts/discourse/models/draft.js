/**
  A data model representing a draft post

  @class Draft
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Draft = Discourse.Model.extend({});

Discourse.Draft.reopenClass({

  clear: function(key, sequence) {
    return Discourse.ajax("/draft.json", {
      type: 'DELETE',
      data: {
        draft_key: key,
        sequence: sequence
      }
    });
  },

  get: function(key) {
    return Discourse.ajax('/draft.json', {
      data: { draft_key: key },
      dataType: 'json'
    });
  },

  getLocal: function(key, current) {
    // TODO: implement this
    return current;
  },

  save: function(key, sequence, data) {
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
