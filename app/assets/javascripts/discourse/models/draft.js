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
    return $.ajax({
      type: 'DELETE',
      url: "/draft",
      data: {
        draft_key: key,
        sequence: sequence
      }
    });
  },

  get: function(key) {
    var promise,
      _this = this;
    promise = new RSVP.Promise();
    $.ajax({
      url: '/draft',
      data: {
        draft_key: key
      },
      dataType: 'json',
      success: function(data) {
        return promise.resolve(data);
      }
    });
    return promise;
  },

  getLocal: function(key, current) {
    var local;
    return current;
  },

  save: function(key, sequence, data) {
    var promise;
    promise = new RSVP.Promise();
    data = typeof data === "string" ? data : JSON.stringify(data);
    $.ajax({
      type: 'POST',
      url: "/draft",
      data: {
        draft_key: key,
        data: data,
        sequence: sequence
      },
      success: function() {
        /* don't keep local
        */

        /* Discourse.KeyValueStore.remove("draft_#{key}")
        */
        return promise.resolve();
      },
      error: function() {
        /* save local
        */

        /* Discourse.KeyValueStore.set(key: "draft_#{key}", value: data)
        */
        return promise.reject();
      }
    });
    return promise;
  }

});
