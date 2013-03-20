/**
  Our data model for interacting with flagged posts.

  @class FlaggedPost
  @extends Discourse.Post
  @namespace Discourse
  @module Discourse
**/
Discourse.FlaggedPost = Discourse.Post.extend({

  flaggers: (function() {
    var r,
      _this = this;
    r = [];
    this.post_actions.each(function(a) {
      return r.push(_this.userLookup[a.user_id]);
    });
    return r;
  }).property(),

  messages: (function() {
    var r,
      _this = this;
    r = [];
    this.post_actions.each(function(a) {
      if (a.message) {
        return r.push({
          user: _this.userLookup[a.user_id],
          message: a.message
        });
      }
    });
    return r;
  }).property(),

  lastFlagged: (function() {
    return this.post_actions[0].created_at;
  }).property(),

  user: (function() {
    return this.userLookup[this.user_id];
  }).property(),

  topicHidden: (function() {
    return this.get('topic_visible') === 'f';
  }).property('topic_hidden'),

  deletePost: function() {
    if (this.get('post_number') === "1") {
      return $.ajax(Discourse.getURL("/t/") + this.topic_id, { type: 'DELETE', cache: false });
    } else {
      return $.ajax(Discourse.getURL("/posts/") + this.id, { type: 'DELETE', cache: false });
    }
  },

  clearFlags: function() {
    return $.ajax(Discourse.getURL("/admin/flags/clear/") + this.id, { type: 'POST', cache: false });
  },

  hiddenClass: (function() {
    if (this.get('hidden') === "t") return "hidden-post";
  }).property()

});

Discourse.FlaggedPost.reopenClass({
  findAll: function(filter) {
    var result;
    result = Em.A();
    $.ajax({
      url: Discourse.getURL("/admin/flags/") + filter + ".json",
      success: function(data) {
        var userLookup;
        userLookup = {};
        data.users.each(function(u) {
          userLookup[u.id] = Discourse.User.create(u);
        });
        return data.posts.each(function(p) {
          var f;
          f = Discourse.FlaggedPost.create(p);
          f.userLookup = userLookup;
          return result.pushObject(f);
        });
      }
    });
    return result;
  }
});


