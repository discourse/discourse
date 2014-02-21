/**
  The data model for a Group

  @class Group
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
var ALIAS_LEVELS = {
    nobody: 0,
    only_admins: 1,
    mods_and_admins: 2,
    members_mods_and_admins: 3,
    everyone: 99
  },
  aliasLevelOptions = [
    { name: I18n.t("groups.alias_levels.nobody"), value: ALIAS_LEVELS.nobody},
    { name: I18n.t("groups.alias_levels.mods_and_admins"), value: ALIAS_LEVELS.mods_and_admins},
    { name: I18n.t("groups.alias_levels.members_mods_and_admins"), value: ALIAS_LEVELS.members_mods_and_admins},
    { name: I18n.t("groups.alias_levels.everyone"), value: ALIAS_LEVELS.everyone}
  ];

Discourse.Group = Discourse.Model.extend({
  loadedUsers: false,

  userCountDisplay: function(){
    var c = this.get('user_count');
    // don't display zero its ugly
    if(c > 0) {
      return c;
    }
  }.property('user_count'),

  // TODO: Refactor so adminGroups doesn't store the groups inside itself either.
  findMembers: function() {
    return Discourse.ajax('/groups/' + this.get('name') + '/members').then(function(result) {
      return result.map(function(u) { return Discourse.User.create(u) });
    });
  },

  loadUsers: function() {
    var id = this.get('id');
    if(id && !this.get('loadedUsers')) {
      var self = this;
      return this.findMembers().then(function(users) {
        self.set('users', users);
        self.set('loadedUsers', true);
        return self;
      });
    }
    return Ember.RSVP.resolve(this);
  },

  usernames: function(key, value) {
    var users = this.get('users');
    if (arguments.length > 1) {
      this.set('_usernames', value);
    } else {
      var usernames = "";
      if(users) {
        usernames = users.map(function(user) {
          return user.get('username');
        }).join(',');
      }
      this.set('_usernames', usernames);
    }
    return this.get('_usernames');
  }.property('users.@each.username'),

  destroy: function(){
    if(!this.id) return;

    var self = this;
    this.set('disableSave', true);

    return Discourse.ajax("/admin/groups/" + this.get('id'), {type: "DELETE"})
      .then(function(){
        return true;
      }, function() {
        self.set('disableSave', false);
        bootbox.alert(I18n.t("admin.groups.delete_failed"));
        return false;
      });
  },

  create: function(){
    var self = this;
    self.set('disableSave', true);

    return Discourse.ajax("/admin/groups", {type: "POST", data: {
      group: {
        name: this.get('name'),
        alias_level: this.get('alias_level'),
        usernames: this.get('usernames')
      }
    }}).then(function(resp) {
      self.set('disableSave', false);
      self.set('id', resp.id);
    }, function (error) {
      self.set('disableSave', false);
      if (error && error.responseText) {
        bootbox.alert($.parseJSON(error.responseText).errors);
      }
      else {
        bootbox.alert(I18n.t('generic_error'));
      }
    });
  },

  save: function(){
    var self = this;
    self.set('disableSave', true);

    return Discourse.ajax("/admin/groups/" + this.get('id'), {
      type: "PUT",
      data: {
        group: {
          name: this.get('name'),
          alias_level: this.get('alias_level'),
          usernames: this.get('usernames')
        }
      }
    }).then(function(){
      self.set('disableSave', false);
    }, function(e){
      var message = $.parseJSON(e.responseText).errors;
      bootbox.alert(message);
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
  findAll: function(){
    return Discourse.ajax("/admin/groups.json").then(function(groups){
      var list = Discourse.SelectableArray.create();
      _.each(groups,function(group){
        list.addObject(Discourse.Group.create(group));
      });
      return list;
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
  },

  aliasLevelOptions: function() {
    return aliasLevelOptions;
  }
});
