/**
  Our data model for dealing with users from the admin section.

  @class AdminUser
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUser = Discourse.Model.extend({
  path: (function() {
    return Discourse.getURL("/users/") + (this.get('username_lower'));
  }).property('username'),

  adminPath: (function() {
    return Discourse.getURL("/admin/users/") + (this.get('username_lower'));
  }).property('username'),


  deleteAllPosts: function() {
    var user = this;
    this.set('can_delete_all_posts', false);
    Discourse.ajax(Discourse.getURL("/admin/users/") + (this.get('id')) + "/delete_all_posts", {type: 'PUT'}).then(function(result){
      user.set('post_count', 0);
    });
  },

  // Revoke the user's admin access
  revokeAdmin: function() {
    this.set('admin', false);
    this.set('can_grant_admin', true);
    this.set('can_revoke_admin', false);
    return Discourse.ajax(Discourse.getURL("/admin/users/") + (this.get('id')) + "/revoke_admin", {type: 'PUT'});
  },

  grantAdmin: function() {
    this.set('admin', true);
    this.set('can_grant_admin', false);
    this.set('can_revoke_admin', true);
    Discourse.ajax(Discourse.getURL("/admin/users/") + (this.get('id')) + "/grant_admin", {type: 'PUT'});
  },

  // Revoke the user's moderation access
  revokeModeration: function() {
    this.set('moderator', false);
    this.set('can_grant_moderation', true);
    this.set('can_revoke_moderation', false);
    return Discourse.ajax(Discourse.getURL("/admin/users/") + (this.get('id')) + "/revoke_moderation", {type: 'PUT'});
  },

  grantModeration: function() {
    this.set('moderator', true);
    this.set('can_grant_moderation', false);
    this.set('can_revoke_moderation', true);
    Discourse.ajax(Discourse.getURL("/admin/users/") + (this.get('id')) + "/grant_moderation", {type: 'PUT'});
  },

  refreshBrowsers: function() {
    Discourse.ajax(Discourse.getURL("/admin/users/") + (this.get('id')) + "/refresh_browsers", {type: 'POST'});
    bootbox.alert("Message sent to all clients!");
  },

  approve: function() {
    this.set('can_approve', false);
    this.set('approved', true);
    this.set('approved_by', Discourse.get('currentUser'));
    Discourse.ajax(Discourse.getURL("/admin/users/") + (this.get('id')) + "/approve", {type: 'PUT'});
  },

  username_lower: (function() {
    return this.get('username').toLowerCase();
  }).property('username'),

  trustLevel: (function() {
    return Discourse.get('site.trust_levels').findProperty('id', this.get('trust_level'));
  }).property('trust_level'),

  isBanned: (function() {
    return this.get('is_banned') === true;
  }).property('is_banned'),

  canBan: (function() {
    return !this.get('admin') && !this.get('moderator');
  }).property('admin', 'moderator'),

  banDuration: (function() {
    var banned_at = Date.create(this.banned_at);
    var banned_till = Date.create(this.banned_till);
    return banned_at.short() + " - " + banned_till.short();
  }).property('banned_till', 'banned_at'),

  ban: function() {
    var duration = parseInt(window.prompt(Em.String.i18n('admin.user.ban_duration')), 10);
    if (duration > 0) {
      Discourse.ajax(Discourse.getURL("/admin/users/") + this.id + "/ban", {
        type: 'PUT',
        data: {duration: duration}
      }).then(function () {
        // succeeded
        window.location.reload();
      }, function(e) {
        // failure
        var error = Em.String.i18n('admin.user.ban_failed', { error: "http: " + e.status + " - " + e.body });
        bootbox.alert(error);
      });
    }
  },

  unban: function() {
    Discourse.ajax(Discourse.getURL("/admin/users/") + this.id + "/unban", {
      type: 'PUT'
    }).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = Em.String.i18n('admin.user.unban_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  impersonate: function() {
    Discourse.ajax(Discourse.getURL("/admin/impersonate"), {
      type: 'POST',
      data: { username_or_email: this.get('username') }
    }).then(function() {
      // succeeded
      document.location = "/";
    }, function(e) {
      // failed
      if (e.status === 404) {
        bootbox.alert(Em.String.i18n('admin.impersonate.not_found'));
      } else {
        bootbox.alert(Em.String.i18n('admin.impersonate.invalid'));
      }
    });
  },

  deleteForbidden: function() {
    return (this.get('post_count') > 0);
  }.property('post_count'),

  deleteButtonTitle: function() {
    if (this.get('deleteForbidden')) {
      return Em.String.i18n('admin.user.delete_forbidden');
    } else {
      return null;
    }
  }.property('deleteForbidden'),

  destroy: function() {
    var user = this;
    bootbox.confirm(Em.String.i18n("admin.user.delete_confirm"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), function(result) {
      if(result) {
        Discourse.ajax(Discourse.getURL("/admin/users/") + user.get('id') + '.json', { type: 'DELETE' }).then(function(data) {
          if (data.deleted) {
            bootbox.alert(Em.String.i18n("admin.user.deleted"), function() {
              document.location = "/admin/users/list/active";
            });
          } else {
            bootbox.alert(Em.String.i18n("admin.user.delete_failed"));
            if (data.user) {
              user.mergeAttributes(data.user);
            }
          }
        }, function(jqXHR, status, error) {
          Discourse.AdminUser.find( user.get('username') ).then(function(u){ user.mergeAttributes(u); });
          bootbox.alert(Em.String.i18n("admin.user.delete_failed"));
        });
      }
    });
  }

});

Discourse.AdminUser.reopenClass({

  bulkApprove: function(users) {
    users.each(function(user) {
      user.set('approved', true);
      user.set('can_approve', false);
      return user.set('selected', false);
    });
    return Discourse.ajax(Discourse.getURL("/admin/users/approve-bulk"), {
      type: 'PUT',
      data: {
        users: users.map(function(u) {
          return u.id;
        })
      }
    });
  },

  find: function(username) {
    return Discourse.ajax({url: Discourse.getURL("/admin/users/") + username}).then(function (result) {
      return Discourse.AdminUser.create(result);
    });
  },

  findAll: function(query, filter, doneCallback) {
    var result = Em.A();
    Discourse.ajax({
      url: Discourse.getURL("/admin/users/list/") + query + ".json",
      data: { filter: filter }
    }).then(function(users) {
      users.each(function(u) {
        result.pushObject(Discourse.AdminUser.create(u));
      });
      if( doneCallback ) { doneCallback(); }
    });
    return result;
  }
});
