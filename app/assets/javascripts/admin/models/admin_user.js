/**
  Our data model for dealing with users from the admin section.

  @class AdminUser
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUser = Discourse.User.extend({

  /**
    Generates an API key for the user. Will regenerate if they already have one.

    @method generateApiKey
    @returns {Promise} a promise that resolves to the newly generated API key
  **/
  generateApiKey: function() {
    var self = this;
    return Discourse.ajax("/admin/users/" + this.get('id') + "/generate_api_key", {type: 'POST'}).then(function (result) {
      var apiKey = Discourse.ApiKey.create(result.api_key);
      self.set('api_key', apiKey);
      return apiKey;
    });
  },

  /**
    Revokes a user's current API key

    @method revokeApiKey
    @returns {Promise} a promise that resolves when the API key has been deleted
  **/
  revokeApiKey: function() {
    var self = this;
    return Discourse.ajax("/admin/users/" + this.get('id') + "/revoke_api_key", {type: 'DELETE'}).then(function (result) {
      self.set('api_key', null);
    });
  },

  deleteAllPosts: function() {
    this.set('can_delete_all_posts', false);
    var user = this;
    var message = I18n.t('admin.user.delete_all_posts_confirm', {posts: user.get('post_count'), topics: user.get('topic_count')});
    var buttons = [{
      "label": I18n.t("composer.cancel"),
      "class": "cancel",
      "link":  true,
      "callback": function() {
        user.set('can_delete_all_posts', true);
      }
    }, {
      "label": '<i class="icon icon-warning-sign"></i> ' + I18n.t("admin.user.delete_all_posts"),
      "class": "btn btn-danger",
      "callback": function() {
        Discourse.ajax("/admin/users/" + (user.get('id')) + "/delete_all_posts", {type: 'PUT'}).then(function(result){
          user.set('post_count', 0);
        });
      }
    }];
    bootbox.dialog(message, buttons, {"classes": "delete-all-posts"});
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

  setOriginalTrustLevel: function() {
    this.set('originalTrustLevel', this.get('trust_level'));
  },

  trustLevels: function() {
    return Discourse.Site.currentProp('trustLevels');
  }.property(),

  dirty: Discourse.computed.propertyNotEqual('originalTrustLevel', 'trustLevel.id'),

  saveTrustLevel: function() {
    Discourse.ajax("/admin/users/" + this.id + "/trust_level", {
      type: 'PUT',
      data: {level: this.get('trustLevel.id')}
    }).then(function () {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failure
      var error = I18n.t('admin.user.trust_level_change_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  restoreTrustLevel: function() {
    this.set('trustLevel.id', this.get('originalTrustLevel'));
  },

  isBanned: Em.computed.equal('is_banned', true),
  canBan: Em.computed.not('staff'),

  banDuration: function() {
    var banned_at = moment(this.banned_at);
    var banned_till = moment(this.banned_till);
    return banned_at.format('L') + " - " + banned_till.format('L');
  }.property('banned_till', 'banned_at'),

  ban: function(duration, reason) {
    return Discourse.ajax("/admin/users/" + this.id + "/ban", {
      type: 'PUT',
      data: {duration: duration, reason: reason}
    });
  },

  unban: function() {
    Discourse.ajax("/admin/users/" + this.id + "/unban", {
      type: 'PUT'
    }).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = I18n.t('admin.user.unban_failed', { error: "http: " + e.status + " - " + e.body });
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
        bootbox.alert(I18n.t('admin.impersonate.not_found'));
      } else {
        bootbox.alert(I18n.t('admin.impersonate.invalid'));
      }
    });
  },

  activate: function() {
    Discourse.ajax('/admin/users/' + this.id + '/activate', {type: 'PUT'}).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = I18n.t('admin.user.activate_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  deactivate: function() {
    Discourse.ajax('/admin/users/' + this.id + '/deactivate', {type: 'PUT'}).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = I18n.t('admin.user.deactivate_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  unblock: function() {
    Discourse.ajax('/admin/users/' + this.id + '/unblock', {type: 'PUT'}).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = I18n.t('admin.user.unblock_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  block: function() {
    Discourse.ajax('/admin/users/' + this.id + '/block', {type: 'PUT'}).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = I18n.t('admin.user.block_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  sendActivationEmail: function() {
    Discourse.ajax('/users/' + this.get('username') + '/send_activation_email', {type: 'POST'}).then(function() {
      // succeeded
      bootbox.alert( I18n.t('admin.user.activation_email_sent') );
    }, function(e) {
      // failed
      var error = I18n.t('admin.user.send_activation_email_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  deleteForbidden: function() {
    return (!this.get('can_be_deleted') || this.get('post_count') > 0);
  }.property('post_count'),

  deleteButtonTitle: function() {
    if (this.get('deleteForbidden')) {
      return I18n.t('admin.user.delete_forbidden', {count: Discourse.SiteSettings.delete_user_max_age});
    } else {
      return null;
    }
  }.property('deleteForbidden'),

  destroy: function() {
    var user = this;

    var performDestroy = function(block) {
      var formData = { context: window.location.pathname };
      if (block) {
        formData["block_email"] = true;
        formData["block_urls"] = true;
        formData["block_ip"] = true;
      }
      Discourse.ajax("/admin/users/" + user.get('id') + '.json', {
        type: 'DELETE',
        data: formData
      }).then(function(data) {
        if (data.deleted) {
          bootbox.alert(I18n.t("admin.user.deleted"), function() {
            document.location = "/admin/users/list/active";
          });
        } else {
          bootbox.alert(I18n.t("admin.user.delete_failed"));
          if (data.user) {
            user.mergeAttributes(data.user);
          }
        }
      }, function(jqXHR, status, error) {
        Discourse.AdminUser.find( user.get('username') ).then(function(u){ user.mergeAttributes(u); });
        bootbox.alert(I18n.t("admin.user.delete_failed"));
      });
    };

    var message = I18n.t("admin.user.delete_confirm");

    var buttons = [{
      "label": I18n.t("composer.cancel"),
      "class": "cancel",
      "link":  true
    }, {
      "label": '<i class="icon icon-warning-sign"></i> ' + I18n.t('admin.user.delete_dont_block'),
      "class": "btn",
      "callback": function(){
        performDestroy(false);
      }
    }, {
      "label": '<i class="icon icon-warning-sign"></i> ' + I18n.t('admin.user.delete_and_block'),
      "class": "btn",
      "callback": function(){
        performDestroy(true);
      }
    }];

    bootbox.dialog(message, buttons, {"classes": "delete-user-modal"});
  },

  deleteAsSpammer: function(successCallback) {
    var user = this;
    var message = I18n.t('flagging.delete_confirm', {posts: user.get('post_count'), topics: user.get('topic_count'), email: user.get('email'), ip_address: user.get('ip_address')});
    var buttons = [{
      "label": I18n.t("composer.cancel"),
      "class": "cancel",
      "link":  true
    }, {
      "label": '<i class="icon icon-warning-sign"></i> ' + I18n.t("flagging.yes_delete_spammer"),
      "class": "btn btn-danger",
      "callback": function() {
        Discourse.ajax("/admin/users/" + user.get('id') + '.json', {
          type: 'DELETE',
          data: {delete_posts: true, block_email: true, block_urls: true, block_ip: true, context: window.location.pathname}
        }).then(function(data) {
          if (data.deleted) {
            bootbox.alert(I18n.t("admin.user.deleted"), function() {
              if (successCallback) successCallback();
            });
          } else {
            bootbox.alert(I18n.t("admin.user.delete_failed"));
          }
        }, function(jqXHR, status, error) {
          bootbox.alert(I18n.t("admin.user.delete_failed"));
        });
      }
    }];
    bootbox.dialog(message, buttons, {"classes": "flagging-delete-spammer"});
  },

  loadDetails: function() {
    var model = this;
    if (model.get('loadedDetails')) { return Ember.RSVP.resolve(model); }

    return Discourse.AdminUser.find(model.get('username_lower')).then(function (result) {
      model.setProperties(result);
      model.set('loadedDetails', true);
    });
  }

});

Discourse.AdminUser.reopenClass({

  bulkApprove: function(users) {
    _.each(users, function(user) {
      user.set('approved', true);
      user.set('can_approve', false);
      return user.set('selected', false);
    });

    bootbox.alert(I18n.t("admin.user.approve_bulk_success"));

    return Discourse.ajax("/admin/users/approve-bulk", {
      type: 'PUT',
      data: {
        users: users.map(function(u) {
          return u.id;
        })
      }
    });
  },

  bulkReject: function(users) {
    _.each(users, function(user){
      user.set('can_approve', false);
      user.set('selected', false);
    });

    return Discourse.ajax("/admin/users/reject-bulk", {
      type: 'DELETE',
      data: {
        users: users.map(function(u) { return u.id; }),
        context: window.location.pathname
      }
    });
  },

  find: function(username) {
    return Discourse.ajax("/admin/users/" + username).then(function (result) {
      result.loadedDetails = true;
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
