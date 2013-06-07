/**
  Our data model for dealing with users from the admin section.

  @class AdminUser
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUser = Discourse.User.extend({

  deleteAllPosts: function() {
    var user = this;
    this.set('can_delete_all_posts', false);
    Discourse.ajax("/admin/users/" + (this.get('id')) + "/delete_all_posts", {type: 'PUT'}).then(function(result){
      user.set('post_count', 0);
    });
  },

  // Revoke the user's admin access
  revokeAdmin: function() {
    this.set('admin', false);
    this.set('can_grant_admin', true);
    this.set('can_revoke_admin', false);
    return Discourse.ajax("/admin/users/" + (this.get('id')) + "/revoke_admin", {type: 'PUT'});
  },

  grantAdmin: function() {
    this.set('admin', true);
    this.set('can_grant_admin', false);
    this.set('can_revoke_admin', true);
    Discourse.ajax("/admin/users/" + (this.get('id')) + "/grant_admin", {type: 'PUT'});
  },

  // Revoke the user's moderation access
  revokeModeration: function() {
    this.set('moderator', false);
    this.set('can_grant_moderation', true);
    this.set('can_revoke_moderation', false);
    return Discourse.ajax("/admin/users/" + (this.get('id')) + "/revoke_moderation", {type: 'PUT'});
  },

  grantModeration: function() {
    this.set('moderator', true);
    this.set('can_grant_moderation', false);
    this.set('can_revoke_moderation', true);
    Discourse.ajax("/admin/users/" + (this.get('id')) + "/grant_moderation", {type: 'PUT'});
  },

  refreshBrowsers: function() {
    Discourse.ajax("/admin/users/" + (this.get('id')) + "/refresh_browsers", {type: 'POST'});
    bootbox.alert("Message sent to all clients!");
  },

  approve: function() {
    this.set('can_approve', false);
    this.set('approved', true);
    this.set('approved_by', Discourse.User.current());
    Discourse.ajax("/admin/users/" + (this.get('id')) + "/approve", {type: 'PUT'});
  },

  username_lower: (function() {
    return this.get('username').toLowerCase();
  }).property('username'),

  trustLevel: function() {
    var site = Discourse.Site.instance();
    return site.get('trust_levels').findProperty('id', this.get('trust_level'));
  }.property('trust_level'),

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
      Discourse.ajax("/admin/users/" + this.id + "/ban", {
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
    Discourse.ajax("/admin/users/" + this.id + "/unban", {
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
    Discourse.ajax("/admin/impersonate", {
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

  activate: function() {
    Discourse.ajax('/admin/users/' + this.id + '/activate', {type: 'PUT'}).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = Em.String.i18n('admin.user.activate_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  deactivate: function() {
    Discourse.ajax('/admin/users/' + this.id + '/deactivate', {type: 'PUT'}).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = Em.String.i18n('admin.user.deactivate_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  unblock: function() {
    Discourse.ajax('/admin/users/' + this.id + '/unblock', {type: 'PUT'}).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = Em.String.i18n('admin.user.unblock_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  block: function() {
    Discourse.ajax('/admin/users/' + this.id + '/block', {type: 'PUT'}).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = Em.String.i18n('admin.user.block_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  sendActivationEmail: function() {
    Discourse.ajax('/users/' + this.get('username') + '/send_activation_email').then(function() {
      // succeeded
      bootbox.alert( Em.String.i18n('admin.user.activation_email_sent') );
    }, function(e) {
      // failed
      var error = Em.String.i18n('admin.user.send_activation_email_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
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
        Discourse.ajax("/admin/users/" + user.get('id') + '.json', { type: 'DELETE' }).then(function(data) {
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

    bootbox.alert(Em.String.i18n("admin.user.approve_bulk_success"));

    return Discourse.ajax("/admin/users/approve-bulk", {
      type: 'PUT',
      data: {
        users: users.map(function(u) {
          return u.id;
        })
      }
    });
  },

  find: function(username) {
    return Discourse.ajax("/admin/users/" + username).then(function (result) {
      return Discourse.AdminUser.create(result);
    });
  },

  findAll: function(query, filter) {
    return Discourse.ajax("/admin/users/list/" + query + ".json", {
      data: { filter: filter }
    }).then(function(users) {
      return users.map(function(u) {
        return Discourse.AdminUser.create(u);
      });
    });
  }
});
