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

  groupAdded: function(added){
    var self = this;
    return Discourse.ajax("/admin/users/" + this.get('id') + "/groups", {
      type: 'POST',
      data: {group_id: added.id}
    }).then(function () {
      self.get('groups').pushObject(added);
    });
  },

  groupRemoved: function(removed){
    var self = this;
    return Discourse.ajax("/admin/users/" + this.get('id') + "/groups/" + removed.id, {
      type: 'DELETE'
    }).then(function () {
      self.set('groups.[]', self.get('groups').rejectBy("id", removed.id));
    });
  },

  /**
    Revokes a user's current API key

    @method revokeApiKey
    @returns {Promise} a promise that resolves when the API key has been deleted
  **/
  revokeApiKey: function() {
    var self = this;
    return Discourse.ajax("/admin/users/" + this.get('id') + "/revoke_api_key", {type: 'DELETE'}).then(function () {
      self.set('api_key', null);
    });
  },

  deleteAllPostsExplanation: function() {
    if (!this.get('can_delete_all_posts')) {
      if (this.get('post_count') > Discourse.SiteSettings.delete_all_posts_max) {
        return I18n.t('admin.user.cant_delete_all_too_many_posts', {count: Discourse.SiteSettings.delete_all_posts_max});
      } else {
        return I18n.t('admin.user.cant_delete_all_posts', {count: Discourse.SiteSettings.delete_user_max_post_age});
      }
    } else {
      return null;
    }
  }.property('can_delete_all_posts'),

  deleteAllPosts: function() {
    var user = this;
    var message = I18n.t('admin.user.delete_all_posts_confirm', {posts: user.get('post_count'), topics: user.get('topic_count')});
    var buttons = [{
      "label": I18n.t("composer.cancel"),
      "class": "cancel-inline",
      "link":  true
    }, {
      "label": '<i class="fa fa-exclamation-triangle"></i> ' + I18n.t("admin.user.delete_all_posts"),
      "class": "btn btn-danger",
      "callback": function() {
        Discourse.ajax("/admin/users/" + (user.get('id')) + "/delete_all_posts", {type: 'PUT'}).then(function(){
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
    bootbox.alert(I18n.t("admin.user.refresh_browsers_message"));
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
      var error;
      if (e.responseJSON && e.responseJSON.errors) {
        error = e.responseJSON.errors[0];
      }
      error = error || I18n.t('admin.user.trust_level_change_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  restoreTrustLevel: function() {
    this.set('trustLevel.id', this.get('originalTrustLevel'));
  },

  lockTrustLevel: function(locked) {
    Discourse.ajax("/admin/users/" + this.id + "/trust_level_lock", {
      type: 'PUT',
      data: { locked: !!locked }
    }).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failure
      var error;
      if (e.responseJSON && e.responseJSON.errors) {
        error = e.responseJSON.errors[0];
      }
      error = error || I18n.t('admin.user.trust_level_change_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  canLockTrustLevel: function(){
    return this.get('trust_level') < 4;
  }.property('trust_level'),

  isSuspended: Em.computed.equal('suspended', true),
  canSuspend: Em.computed.not('staff'),

  suspendDuration: function() {
    var suspended_at = moment(this.suspended_at);
    var suspended_till = moment(this.suspended_till);
    return suspended_at.format('L') + " - " + suspended_till.format('L');
  }.property('suspended_till', 'suspended_at'),

  suspend: function(duration, reason) {
    return Discourse.ajax("/admin/users/" + this.id + "/suspend", {
      type: 'PUT',
      data: {duration: duration, reason: reason}
    });
  },

  unsuspend: function() {
    Discourse.ajax("/admin/users/" + this.id + "/unsuspend", {
      type: 'PUT'
    }).then(function() {
      // succeeded
      window.location.reload();
    }, function(e) {
      // failed
      var error = I18n.t('admin.user.unsuspend_failed', { error: "http: " + e.status + " - " + e.body });
      bootbox.alert(error);
    });
  },

  log_out: function(){
    Discourse.ajax("/admin/users/" + this.id + "/log_out", {
      type: 'POST',
      data: { username_or_email: this.get('username') }
    }).then(
      function(){
        bootbox.alert(I18n.t("admin.user.logged_out"));
      }
      );
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
    Discourse.ajax('/users/action/send_activation_email', {data: {username: this.get('username')}, type: 'POST'}).then(function() {
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

  deleteExplanation: function() {
    if (this.get('deleteForbidden')) {
      if (this.get('staff')) {
        return I18n.t('admin.user.delete_forbidden_because_staff');
      } else {
        return I18n.t('admin.user.delete_forbidden', {count: Discourse.SiteSettings.delete_user_max_post_age});
      }
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
          document.location = "/admin/users/list/active";
        } else {
          bootbox.alert(I18n.t("admin.user.delete_failed"));
          if (data.user) {
            user.setProperties(data.user);
          }
        }
      }, function() {
        Discourse.AdminUser.find( user.get('username') ).then(function(u){ user.setProperties(u); });
        bootbox.alert(I18n.t("admin.user.delete_failed"));
      });
    };

    var message = I18n.t("admin.user.delete_confirm");

    var buttons = [{
      "label": I18n.t("composer.cancel"),
      "class": "cancel",
      "link":  true
    }, {
      "label": I18n.t('admin.user.delete_dont_block'),
      "class": "btn",
      "callback": function(){
        performDestroy(false);
      }
    }, {
      "label": '<i class="fa fa-exclamation-triangle"></i>' + I18n.t('admin.user.delete_and_block'),
      "class": "btn btn-danger",
      "callback": function(){
        performDestroy(true);
      }
    }];

    bootbox.dialog(message, buttons, {"classes": "delete-user-modal"});
  },

  deleteAsSpammer: function(successCallback) {
    var user = this;

    user.checkEmail().then(function() {
      var data = {
        posts: user.get('post_count'),
        topics: user.get('topic_count'),
        email: user.get('email') || I18n.t("flagging.hidden_email_address"),
        ip_address: user.get('ip_address') || I18n.t("flagging.ip_address_missing")
      };
      var message = I18n.t('flagging.delete_confirm', data);
      var buttons = [{
        "label": I18n.t("composer.cancel"),
        "class": "cancel-inline",
        "link":  true
      }, {
        "label": '<i class="fa fa-exclamation-triangle"></i> ' + I18n.t("flagging.yes_delete_spammer"),
        "class": "btn btn-danger",
        "callback": function() {
          Discourse.ajax("/admin/users/" + user.get('id') + '.json', {
            type: 'DELETE',
            data: {
              delete_posts: true,
              block_email: true,
              block_urls: true,
              block_ip: true,
              delete_as_spammer: true,
              context: window.location.pathname
            }
          }).then(function(result) {
            if (result.deleted) {
              if (successCallback) successCallback();
            } else {
              bootbox.alert(I18n.t("admin.user.delete_failed"));
            }
          }, function() {
            bootbox.alert(I18n.t("admin.user.delete_failed"));
          });
        }
      }];
      bootbox.dialog(message, buttons, {"classes": "flagging-delete-spammer"});
    });

  },

  loadDetails: function() {
    var model = this;
    if (model.get('loadedDetails')) { return Ember.RSVP.resolve(model); }

    return Discourse.AdminUser.find(model.get('username_lower')).then(function (result) {
      model.setProperties(result);
      model.set('loadedDetails', true);
    });
  },

  tl3Requirements: function() {
    if (this.get('tl3_requirements')) {
      return Discourse.TL3Requirements.create(this.get('tl3_requirements'));
    }
  }.property('tl3_requirements'),

  suspendedBy: function() {
    if (this.get('suspended_by')) {
      return Discourse.AdminUser.create(this.get('suspended_by'));
    }
  }.property('suspended_by'),

  approvedBy: function() {
    if (this.get('approved_by')) {
      return Discourse.AdminUser.create(this.get('approved_by'));
    }
  }.property('approved_by')

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
    return Discourse.ajax("/admin/users/" + username + ".json").then(function (result) {
      result.loadedDetails = true;
      return Discourse.AdminUser.create(result);
    });
  },

  findAll: function(query, filter) {
    return Discourse.ajax("/admin/users/list/" + query + ".json", {
      data: filter
    }).then(function(users) {
      return users.map(function(u) {
        return Discourse.AdminUser.create(u);
      });
    });
  }
});
