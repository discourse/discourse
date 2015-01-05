/**
  The data model for a Group

  @class Group
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Group = Discourse.Model.extend({
  limit: 50,
  offset: 0,
  user_count: 0,

  userCountDisplay: function(){
    var c = this.get('user_count');
    // don't display zero its ugly
    if (c > 0) { return c; }
  }.property('user_count'),

  findMembers: function() {
    if (Em.isEmpty(this.get('name'))) { return ; }

    var self = this, offset = Math.min(this.get("user_count"), Math.max(this.get("offset"), 0));

    return Discourse.ajax('/groups/' + this.get('name') + '/members.json', {
      data: {
        limit: this.get("limit"),
        offset: offset
      }
    }).then(function(result) {
      self.setProperties({
        user_count: result.meta.total,
        limit: result.meta.limit,
        offset: result.meta.offset,
        members: result.members.map(function(member) { return Discourse.User.create(member); })
      });
    });
  },

  removeMember: function(member) {
    var self = this;
    return Discourse.ajax('/admin/groups/' + this.get('id') + '/members.json', {
      type: "DELETE",
      data: { user_id: member.get("id") }
    }).then(function() {
      // reload member list
      self.findMembers();
    });
  },

  addMembers: function(usernames) {
    var self = this;
    return Discourse.ajax('/admin/groups/' + this.get('id') + '/members.json', {
      type: "PUT",
      data: { usernames: usernames }
    }).then(function() {
      // reload member list
      self.findMembers();
    })
  },

  asJSON: function() {
    return {
      name: this.get('name'),
      alias_level: this.get('alias_level'),
      visible: !!this.get('visible')
    };
  },

  create: function(){
    var self = this;
    return Discourse.ajax("/admin/groups", { type: "POST", data: this.asJSON() }).then(function(resp) {
      self.set('id', resp.basic_group.id);
    });
  },

  save: function(){
    return Discourse.ajax("/admin/groups/" + this.get('id'), { type: "PUT", data: this.asJSON() });
  },

  destroy: function(){
    if (!this.get('id')) { return };
    return Discourse.ajax("/admin/groups/" + this.get('id'), {type: "DELETE"});
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
