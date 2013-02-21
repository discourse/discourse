(function() {

  /**
    Our data model for dealing with users from the admin section.

    @class AdminUser    
    @extends Discourse.Model
    @namespace Discourse
    @module Discourse
  **/ 
  window.Discourse.AdminUser = Discourse.Model.extend({
    
    deleteAllPosts: function() {
      this.set('can_delete_all_posts', false);
      jQuery.ajax("/admin/users/" + (this.get('id')) + "/delete_all_posts", {type: 'PUT'});
    },

    // Revoke the user's admin access
    revokeAdmin: function() {
      this.set('admin', false);
      this.set('can_grant_admin', true);
      this.set('can_revoke_admin', false);
      return jQuery.ajax("/admin/users/" + (this.get('id')) + "/revoke_admin", {type: 'PUT'});
    },

    grantAdmin: function() {
      this.set('admin', true);
      this.set('can_grant_admin', false);
      this.set('can_revoke_admin', true);
      jQuery.ajax("/admin/users/" + (this.get('id')) + "/grant_admin", {type: 'PUT'});
    },

    // Revoke the user's moderation access
    revokeModeration: function() {
      this.set('moderator', false);
      this.set('can_grant_moderation', true);
      this.set('can_revoke_moderation', false);
      return jQuery.ajax("/admin/users/" + (this.get('id')) + "/revoke_moderation", {type: 'PUT'});
    },

    grantModeration: function() {
      this.set('moderator', true);
      this.set('can_grant_moderation', false);
      this.set('can_revoke_moderation', true);
      jQuery.ajax("/admin/users/" + (this.get('id')) + "/grant_moderation", {type: 'PUT'});
    },

    refreshBrowsers: function() {
      jQuery.ajax("/admin/users/" + (this.get('id')) + "/refresh_browsers", {type: 'POST'});
      bootbox.alert("Message sent to all clients!");
    },

    approve: function() {
      this.set('can_approve', false);
      this.set('approved', true);
      this.set('approved_by', Discourse.get('currentUser'));
      jQuery.ajax("/admin/users/" + (this.get('id')) + "/approve", {type: 'PUT'});
    },

    username_lower: (function() {
      return this.get('username').toLowerCase();
    }).property('username'),

    trustLevel: (function() {
      return Discourse.get('site.trust_levels').findProperty('id', this.get('trust_level'));
    }).property('trust_level'),

    canBan: (function() {
      return !this.admin && !this.moderator;
    }).property('admin', 'moderator'),

    banDuration: (function() {
      var banned_at, banned_till;
      banned_at = Date.create(this.banned_at);
      banned_till = Date.create(this.banned_till);
      return "" + (banned_at.short()) + " - " + (banned_till.short());
    }).property('banned_till', 'banned_at'),

    ban: function() {
      var duration,
        _this = this;
      if (duration = parseInt(window.prompt(Em.String.i18n('admin.user.ban_duration')), 10)) {
        if (duration > 0) {
          return jQuery.ajax("/admin/users/" + this.id + "/ban", {
            type: 'PUT',
            data: {duration: duration},
            success: function() {
              window.location.reload();
            },
            error: function(e) {
              var error;
              error = Em.String.i18n('admin.user.ban_failed', {
                error: "http: " + e.status + " - " + e.body
              });
              bootbox.alert(error);
            }
          });
        }
      }
    },

    unban: function() {
      var _this = this;
      return jQuery.ajax("/admin/users/" + this.id + "/unban", {
        type: 'PUT',
        success: function() {
          window.location.reload();
        },
        error: function(e) {
          var error;
          error = Em.String.i18n('admin.user.unban_failed', {
            error: "http: " + e.status + " - " + e.body
          });
          bootbox.alert(error);
        }
      });
    },

    impersonate: function() {
      var _this = this;
      return jQuery.ajax("/admin/impersonate", {
        type: 'POST',
        data: {
          username_or_email: this.get('username')
        },
        success: function() {
          document.location = "/";
        },
        error: function(e) {
          _this.set('loading', false);
          if (e.status === 404) {
            return bootbox.alert(Em.String.i18n('admin.impersonate.not_found'));
          } else {
            return bootbox.alert(Em.String.i18n('admin.impersonate.invalid'));
          }
        }
      });
    }

  });

  window.Discourse.AdminUser.reopenClass({

    bulkApprove: function(users) {
      users.each(function(user) {
        user.set('approved', true);
        user.set('can_approve', false);
        return user.set('selected', false);
      });
      return jQuery.ajax("/admin/users/approve-bulk", {
        type: 'PUT',
        data: {
          users: users.map(function(u) {
            return u.id;
          })
        }
      });
    },

    find: function(username) {
      var promise;
      promise = new RSVP.Promise();
      jQuery.ajax({
        url: "/admin/users/" + username,
        success: function(result) {
          return promise.resolve(Discourse.AdminUser.create(result));
        }
      });
      return promise;
    },

    findAll: function(query, filter) {
      var result;
      result = Em.A();
      jQuery.ajax({
        url: "/admin/users/list/" + query + ".json",
        data: {
          filter: filter
        },
        success: function(users) {
          return users.each(function(u) {
            return result.pushObject(Discourse.AdminUser.create(u));
          });
        }
      });
      return result;
    }
  });

}).call(this);
