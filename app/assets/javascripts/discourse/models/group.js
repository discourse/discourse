/**
  The data model for a Group

  @class Group
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Group = Discourse.Model.extend({

  userCountDisplay: function(){
    var c = this.get('user_count');
    // don't display zero its ugly
    if(c > 0) {
      return c;
    }
  }.property('user_count'),

  findMembers: function() {
    if (Em.isEmpty(this.get('name'))) { return Ember.RSVP.resolve([]); }

    return Discourse.ajax('/groups/' + this.get('name') + '/members').then(function(result) {
      return result.map(function(u) { return Discourse.User.create(u) });
    });
  },

  destroy: function(){
    if(!this.get('id')) return;
    return Discourse.ajax("/admin/groups/" + this.get('id'), {type: "DELETE"});
  },

  asJSON: function() {
    return { group: {
             name: this.get('name'),
             alias_level: this.get('alias_level'),
             visible: !!this.get('visible'),
             usernames: this.get('usernames') } };
  },

  createWithUsernames: function(usernames){
    var self = this,
        json = this.asJSON();
    json.group.usernames = usernames;

    return Discourse.ajax("/admin/groups", {type: "POST", data: json}).then(function(resp) {
      self.set('id', resp.basic_group.id);
    });
  },

  saveWithUsernames: function(usernames){
    var json = this.asJSON();
    json.group.usernames = usernames;
    return Discourse.ajax("/admin/groups/" + this.get('id'), {
      type: "PUT",
      data: json
    });
  },

  findPosts: function(opts) {
    opts = opts || {};

    var data = {};
    if (opts.beforePostId) { data.before_post_id = opts.beforePostId; }

    return Discourse.ajax("/groups/" + this.get('name') + "/posts.json", { data: data }).then(function (posts) {
      return posts.map(function (p) {
        p.user = Discourse.User.create(p.user);
        return Em.Object.create(p);
      });
    });
  }
});

Discourse.Group.reopenClass({
  findAll: function(opts){
    return Discourse.ajax("/admin/groups.json", { data: opts }).then(function(groups){
      return groups.map(function(g) { return Discourse.Group.create(g); });
    });
  },

  findGroupCounts: function(name) {
    return Discourse.ajax("/groups/" + name + "/counts.json").then(function (result) {
      return Em.Object.create(result.counts);
    });
  },

  find: function(name) {
    return Discourse.ajax("/groups/" + name + ".json").then(function(g) {
      return Discourse.Group.create(g.basic_group);
    });
  }
});
