import { iconHTML } from "discourse-common/lib/icon-library";
import { ajax } from "discourse/lib/ajax";
import computed from "ember-addons/ember-computed-decorators";
import { propertyNotEqual } from "discourse/lib/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ApiKey from "admin/models/api-key";
import Group from "discourse/models/group";
import { userPath } from "discourse/lib/url";

const wrapAdmin = user => (user ? AdminUser.create(user) : null);

const AdminUser = Discourse.User.extend({
  adminUserView: true,
  customGroups: Ember.computed.filter(
    "groups",
    g => !g.automatic && Group.create(g)
  ),
  automaticGroups: Ember.computed.filter(
    "groups",
    g => g.automatic && Group.create(g)
  ),

  canViewProfile: Ember.computed.or("active", "staged"),

  @computed("bounce_score", "reset_bounce_score_after")
  bounceScore(bounce_score, reset_bounce_score_after) {
    if (bounce_score > 0) {
      return `${bounce_score} - ${moment(reset_bounce_score_after).format(
        "LL"
      )}`;
    } else {
      return bounce_score;
    }
  },

  @computed("bounce_score")
  bounceScoreExplanation(bounce_score) {
    if (bounce_score === 0) {
      return I18n.t("admin.user.bounce_score_explanation.none");
    } else if (bounce_score < Discourse.SiteSettings.bounce_score_threshold) {
      return I18n.t("admin.user.bounce_score_explanation.some");
    } else {
      return I18n.t("admin.user.bounce_score_explanation.threshold_reached");
    }
  },

  @computed
  bounceLink() {
    return Discourse.getURL("/admin/email/bounced");
  },

  canResetBounceScore: Ember.computed.gt("bounce_score", 0),

  resetBounceScore() {
    return ajax(`/admin/users/${this.get("id")}/reset_bounce_score`, {
      type: "POST"
    }).then(() =>
      this.setProperties({
        bounce_score: 0,
        reset_bounce_score_after: null
      })
    );
  },

  generateApiKey() {
    const self = this;
    return ajax("/admin/users/" + this.get("id") + "/generate_api_key", {
      type: "POST"
    }).then(function(result) {
      const apiKey = ApiKey.create(result.api_key);
      self.set("api_key", apiKey);
      return apiKey;
    });
  },

  groupAdded(added) {
    return ajax("/admin/users/" + this.get("id") + "/groups", {
      type: "POST",
      data: { group_id: added.id }
    }).then(() => this.get("groups").pushObject(added));
  },

  groupRemoved(groupId) {
    return ajax("/admin/users/" + this.get("id") + "/groups/" + groupId, {
      type: "DELETE"
    }).then(() => {
      this.set("groups.[]", this.get("groups").rejectBy("id", groupId));
      if (this.get("primary_group_id") === groupId) {
        this.set("primary_group_id", null);
      }
    });
  },

  revokeApiKey() {
    return ajax("/admin/users/" + this.get("id") + "/revoke_api_key", {
      type: "DELETE"
    }).then(() => this.set("api_key", null));
  },

  deleteAllPosts() {
    let deletedPosts = 0;
    const user = this,
      message = I18n.messageFormat("admin.user.delete_all_posts_confirm_MF", {
        POSTS: user.get("post_count"),
        TOPICS: user.get("topic_count")
      }),
      buttons = [
        {
          label: I18n.t("composer.cancel"),
          class: "d-modal-cancel",
          link: true
        },
        {
          label:
            `${iconHTML("exclamation-triangle")} ` +
            I18n.t("admin.user.delete_all_posts"),
          class: "btn btn-danger",
          callback: () => {
            openProgressModal();
            performDelete();
          }
        }
      ],
      openProgressModal = () => {
        bootbox.dialog(
          `<p>${I18n.t(
            "admin.user.delete_posts_progress"
          )}</p><div class='progress-bar'><span></span></div>`,
          [],
          { classes: "delete-posts-progress" }
        );
      },
      performDelete = () => {
        let deletedPercentage = 0;
        return ajax(`/admin/users/${user.get("id")}/delete_posts_batch`, {
          type: "PUT"
        })
          .then(({ posts_deleted }) => {
            if (posts_deleted === 0) {
              user.set("post_count", 0);
              bootbox.hideAll();
            } else {
              deletedPosts += posts_deleted;
              deletedPercentage = Math.floor(
                (deletedPosts * 100) / user.get("post_count")
              );
              $(".delete-posts-progress .progress-bar > span").css({
                width: `${deletedPercentage}%`
              });
              performDelete();
            }
          })
          .catch(e => {
            bootbox.hideAll();
            let error;
            AdminUser.find(user.get("id")).then(u => user.setProperties(u));
            if (e.responseJSON && e.responseJSON.errors) {
              error = e.responseJSON.errors[0];
            }
            error = error || I18n.t("admin.user.delete_posts_failed");
            bootbox.alert(error);
          });
      };
    bootbox.dialog(message, buttons, { classes: "delete-all-posts" });
  },

  revokeAdmin() {
    return ajax(`/admin/users/${this.get("id")}/revoke_admin`, {
      type: "PUT"
    }).then(() => {
      this.setProperties({
        admin: false,
        can_grant_admin: true,
        can_revoke_admin: false
      });
    });
  },

  grantAdmin() {
    return ajax(`/admin/users/${this.get("id")}/grant_admin`, {
      type: "PUT"
    })
      .then(() => {
        bootbox.alert(I18n.t("admin.user.grant_admin_confirm"));
      })
      .catch(popupAjaxError);
  },

  revokeModeration() {
    const self = this;
    return ajax("/admin/users/" + this.get("id") + "/revoke_moderation", {
      type: "PUT"
    })
      .then(function() {
        self.setProperties({
          moderator: false,
          can_grant_moderation: true,
          can_revoke_moderation: false
        });
      })
      .catch(popupAjaxError);
  },

  grantModeration() {
    const self = this;
    return ajax("/admin/users/" + this.get("id") + "/grant_moderation", {
      type: "PUT"
    })
      .then(function() {
        self.setProperties({
          moderator: true,
          can_grant_moderation: false,
          can_revoke_moderation: true
        });
      })
      .catch(popupAjaxError);
  },

  disableSecondFactor() {
    return ajax(`/admin/users/${this.get("id")}/disable_second_factor`, {
      type: "PUT"
    })
      .then(() => {
        this.set("second_factor_enabled", false);
      })
      .catch(popupAjaxError);
  },

  approve() {
    const self = this;
    return ajax("/admin/users/" + this.get("id") + "/approve", {
      type: "PUT"
    }).then(function() {
      self.setProperties({
        can_approve: false,
        approved: true,
        approved_by: Discourse.User.current()
      });
    });
  },

  setOriginalTrustLevel() {
    this.set("originalTrustLevel", this.get("trust_level"));
  },

  dirty: propertyNotEqual("originalTrustLevel", "trustLevel.id"),

  saveTrustLevel() {
    return ajax("/admin/users/" + this.id + "/trust_level", {
      type: "PUT",
      data: { level: this.get("trustLevel.id") }
    })
      .then(function() {
        window.location.reload();
      })
      .catch(function(e) {
        let error;
        if (e.responseJSON && e.responseJSON.errors) {
          error = e.responseJSON.errors[0];
        }
        error =
          error ||
          I18n.t("admin.user.trust_level_change_failed", {
            error: "http: " + e.status + " - " + e.body
          });
        bootbox.alert(error);
      });
  },

  restoreTrustLevel() {
    this.set("trustLevel.id", this.get("originalTrustLevel"));
  },

  lockTrustLevel(locked) {
    return ajax("/admin/users/" + this.id + "/trust_level_lock", {
      type: "PUT",
      data: { locked: !!locked }
    })
      .then(function() {
        window.location.reload();
      })
      .catch(function(e) {
        let error;
        if (e.responseJSON && e.responseJSON.errors) {
          error = e.responseJSON.errors[0];
        }
        error =
          error ||
          I18n.t("admin.user.trust_level_change_failed", {
            error: "http: " + e.status + " - " + e.body
          });
        bootbox.alert(error);
      });
  },

  @computed("trust_level")
  canLockTrustLevel(trustLevel) {
    return trustLevel < 4;
  },

  canSuspend: Ember.computed.not("staff"),

  @computed("suspended_till", "suspended_at")
  suspendDuration(suspendedTill, suspendedAt) {
    suspendedAt = moment(suspendedAt);
    suspendedTill = moment(suspendedTill);
    return suspendedAt.format("L") + " - " + suspendedTill.format("L");
  },

  suspend(data) {
    return ajax(`/admin/users/${this.id}/suspend`, {
      type: "PUT",
      data
    }).then(result => this.setProperties(result.suspension));
  },

  unsuspend() {
    return ajax(`/admin/users/${this.id}/unsuspend`, {
      type: "PUT"
    }).then(result => this.setProperties(result.suspension));
  },

  logOut() {
    return ajax("/admin/users/" + this.id + "/log_out", {
      type: "POST",
      data: { username_or_email: this.get("username") }
    }).then(function() {
      bootbox.alert(I18n.t("admin.user.logged_out"));
    });
  },

  impersonate() {
    return ajax("/admin/impersonate", {
      type: "POST",
      data: { username_or_email: this.get("username") }
    })
      .then(function() {
        document.location = Discourse.getURL("/");
      })
      .catch(function(e) {
        if (e.status === 404) {
          bootbox.alert(I18n.t("admin.impersonate.not_found"));
        } else {
          bootbox.alert(I18n.t("admin.impersonate.invalid"));
        }
      });
  },

  activate() {
    return ajax("/admin/users/" + this.id + "/activate", {
      type: "PUT"
    })
      .then(function() {
        window.location.reload();
      })
      .catch(function(e) {
        var error = I18n.t("admin.user.activate_failed", {
          error: "http: " + e.status + " - " + e.body
        });
        bootbox.alert(error);
      });
  },

  deactivate() {
    return ajax("/admin/users/" + this.id + "/deactivate", {
      type: "PUT",
      data: { context: document.location.pathname }
    })
      .then(function() {
        window.location.reload();
      })
      .catch(function(e) {
        var error = I18n.t("admin.user.deactivate_failed", {
          error: "http: " + e.status + " - " + e.body
        });
        bootbox.alert(error);
      });
  },

  unsilence() {
    this.set("silencingUser", true);

    return ajax(`/admin/users/${this.id}/unsilence`, {
      type: "PUT"
    })
      .then(result => {
        this.setProperties(result.unsilence);
      })
      .catch(e => {
        let error = I18n.t("admin.user.unsilence_failed", {
          error: `http: ${e.status} - ${e.body}`
        });
        bootbox.alert(error);
      })
      .finally(() => {
        this.set("silencingUser", false);
      });
  },

  silence(data) {
    this.set("silencingUser", true);
    return ajax(`/admin/users/${this.id}/silence`, {
      type: "PUT",
      data
    })
      .then(result => {
        this.setProperties(result.silence);
      })
      .catch(e => {
        let error = I18n.t("admin.user.silence_failed", {
          error: `http: ${e.status} - ${e.body}`
        });
        bootbox.alert(error);
      })
      .finally(() => {
        this.set("silencingUser", false);
      });
  },

  sendActivationEmail() {
    return ajax(userPath("action/send_activation_email"), {
      type: "POST",
      data: { username: this.get("username") }
    })
      .then(function() {
        bootbox.alert(I18n.t("admin.user.activation_email_sent"));
      })
      .catch(popupAjaxError);
  },

  anonymize() {
    const user = this,
      message = I18n.t("admin.user.anonymize_confirm");

    const performAnonymize = function() {
      return ajax("/admin/users/" + user.get("id") + "/anonymize.json", {
        type: "PUT"
      })
        .then(function(data) {
          if (data.success) {
            if (data.username) {
              document.location = Discourse.getURL(
                "/admin/users/" + user.get("id") + "/" + data.username
              );
            } else {
              document.location = Discourse.getURL("/admin/users/list/active");
            }
          } else {
            bootbox.alert(I18n.t("admin.user.anonymize_failed"));
            if (data.user) {
              user.setProperties(data.user);
            }
          }
        })
        .catch(function() {
          bootbox.alert(I18n.t("admin.user.anonymize_failed"));
        });
    };

    const buttons = [
      {
        label: I18n.t("composer.cancel"),
        class: "cancel",
        link: true
      },
      {
        label:
          `${iconHTML("exclamation-triangle")} ` +
          I18n.t("admin.user.anonymize_yes"),
        class: "btn btn-danger",
        callback: function() {
          performAnonymize();
        }
      }
    ];

    bootbox.dialog(message, buttons, { classes: "delete-user-modal" });
  },

  destroy(opts) {
    const user = this,
      message = I18n.t("admin.user.delete_confirm"),
      location = document.location.pathname;

    const performDestroy = function(block) {
      bootbox.dialog(I18n.t("admin.user.deleting_user"));
      let formData = { context: location };
      if (block) {
        formData["block_email"] = true;
        formData["block_urls"] = true;
        formData["block_ip"] = true;
      }
      if (opts && opts.deletePosts) {
        formData["delete_posts"] = true;
      }
      return ajax("/admin/users/" + user.get("id") + ".json", {
        type: "DELETE",
        data: formData
      })
        .then(function(data) {
          if (data.deleted) {
            if (/^\/admin\/users\/list\//.test(location)) {
              document.location = location;
            } else {
              document.location = Discourse.getURL("/admin/users/list/active");
            }
          } else {
            bootbox.alert(I18n.t("admin.user.delete_failed"));
            if (data.user) {
              user.setProperties(data.user);
            }
          }
        })
        .catch(function() {
          AdminUser.find(user.get("id")).then(u => user.setProperties(u));
          bootbox.alert(I18n.t("admin.user.delete_failed"));
        });
    };

    const buttons = [
      {
        label: I18n.t("composer.cancel"),
        class: "btn",
        link: true
      },
      {
        label:
          `${iconHTML("exclamation-triangle")} ` +
          I18n.t("admin.user.delete_and_block"),
        class: "btn btn-danger",
        callback: function() {
          performDestroy(true);
        }
      },
      {
        label: I18n.t("admin.user.delete_dont_block"),
        class: "btn btn-primary",
        callback: function() {
          performDestroy(false);
        }
      }
    ];

    bootbox.dialog(message, buttons, { classes: "delete-user-modal" });
  },

  loadDetails() {
    const user = this;

    if (user.get("loadedDetails")) {
      return Ember.RSVP.resolve(user);
    }

    return AdminUser.find(user.get("id")).then(result => {
      user.setProperties(result);
      user.set("loadedDetails", true);
    });
  },

  @computed("tl3_requirements")
  tl3Requirements(requirements) {
    if (requirements) {
      return this.store.createRecord("tl3Requirements", requirements);
    }
  },

  @computed("suspended_by")
  suspendedBy: wrapAdmin,

  @computed("silenced_by")
  silencedBy: wrapAdmin,

  @computed("approved_by")
  approvedBy: wrapAdmin
});

AdminUser.reopenClass({
  find(user_id) {
    return ajax("/admin/users/" + user_id + ".json").then(result => {
      result.loadedDetails = true;
      return AdminUser.create(result);
    });
  },

  findAll(query, filter) {
    return ajax("/admin/users/list/" + query + ".json", {
      data: filter
    }).then(function(users) {
      return users.map(u => AdminUser.create(u));
    });
  }
});

export default AdminUser;
