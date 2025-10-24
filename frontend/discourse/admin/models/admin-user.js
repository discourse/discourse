import { filter, gt, lt, not, or } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { propertyNotEqual } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { trackedArray } from "discourse/lib/tracked-tools";
import { userPath } from "discourse/lib/url";
import Group from "discourse/models/group";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class AdminUser extends User {
  /**
   * Retrieves user details for the specified user ID and formats the result based on the provided options.
   *
   * @param {string|number} user_id - The ID of the user to be retrieved.
   * @param {Object} [opts] - Options to customize the result format.
   * @param {boolean} [opts.raw=false] - If true, returns the raw response instead of formatting it using AdminUser.create.
   * @return {Promise<Object|AdminUser>} A promise that resolves with either the raw response object or an instance of AdminUser.
   */
  static async find(user_id, opts = { raw: false }) {
    const result = await ajax(`/admin/users/${user_id}.json`);
    result.loadedDetails = true;
    return opts?.raw ? result : AdminUser.create(result);
  }

  static findAll(query, userFilter) {
    return ajax(`/admin/users/list/${query}.json`, {
      data: userFilter,
    }).then((users) => users.map((u) => AdminUser.create(u)));
  }

  adminUserView = true;

  @trackedArray groups;

  @filter("groups", (g) => !g.automatic && Group.create(g)) customGroups;
  @filter("groups", (g) => g.automatic && Group.create(g)) automaticGroups;
  @or("active", "staged") canViewProfile;
  @gt("bounce_score", 0) canResetBounceScore;
  @propertyNotEqual("originalTrustLevel", "trust_level") dirty;
  @lt("trust_level", 4) canLockTrustLevel;
  @not("staff") canSuspend;
  @not("staff") canSilence;

  @discourseComputed("bounce_score", "reset_bounce_score_after")
  bounceScore(bounce_score, reset_bounce_score_after) {
    if (bounce_score > 0) {
      return `${bounce_score} - ${moment(reset_bounce_score_after).format(
        "LL"
      )}`;
    } else {
      return bounce_score;
    }
  }

  @discourseComputed("bounce_score")
  bounceScoreExplanation(bounce_score) {
    if (bounce_score === 0) {
      return i18n("admin.user.bounce_score_explanation.none");
    } else if (bounce_score < this.siteSettings.bounce_score_threshold) {
      return i18n("admin.user.bounce_score_explanation.some");
    } else {
      return i18n("admin.user.bounce_score_explanation.threshold_reached");
    }
  }

  @discourseComputed
  bounceLink() {
    return getURL("/admin/email-logs/bounced");
  }

  resetBounceScore() {
    return ajax(`/admin/users/${this.id}/reset-bounce-score`, {
      type: "POST",
    }).then(() =>
      this.setProperties({
        bounce_score: 0,
        reset_bounce_score_after: null,
      })
    );
  }

  groupAdded(added) {
    return ajax(`/admin/users/${this.id}/groups`, {
      type: "POST",
      data: { group_id: added.id },
    }).then(() => this.groups.pushObject(added));
  }

  groupRemoved(groupId) {
    return ajax(`/admin/users/${this.id}/groups/${groupId}`, {
      type: "DELETE",
    }).then(() => {
      this.groups = this.groups.filter((group) => group.id !== groupId);
      if (this.primary_group_id === groupId) {
        this.set("primary_group_id", null);
      }
    });
  }

  deleteAllPosts() {
    return ajax(`/admin/users/${this.get("id")}/delete_posts_batch`, {
      type: "PUT",
    });
  }

  revokeAdmin() {
    return ajax(`/admin/users/${this.id}/revoke_admin`, {
      type: "PUT",
    }).then((resp) => {
      this.setProperties({
        admin: false,
        can_grant_admin: true,
        can_revoke_admin: false,
        can_be_merged: resp.can_be_merged,
        can_be_anonymized: resp.can_be_anonymized,
        can_be_deleted: resp.can_be_deleted,
        can_delete_all_posts: resp.can_delete_all_posts,
      });
    });
  }

  grantAdmin(data) {
    return ajax(`/admin/users/${this.id}/grant_admin`, {
      type: "PUT",
      data,
    }).then((resp) => {
      if (resp.success && !resp.email_confirmation_required) {
        this.setProperties({
          admin: true,
          can_grant_admin: false,
          can_revoke_admin: true,
        });
      }

      return resp;
    });
  }

  revokeModeration() {
    return ajax(`/admin/users/${this.id}/revoke_moderation`, {
      type: "PUT",
    })
      .then((resp) => {
        this.setProperties({
          moderator: false,
          can_grant_moderation: true,
          can_revoke_moderation: false,
          can_be_merged: resp.can_be_merged,
          can_be_anonymized: resp.can_be_anonymized,
        });
      })
      .catch(popupAjaxError);
  }

  grantModeration() {
    return ajax(`/admin/users/${this.id}/grant_moderation`, {
      type: "PUT",
    })
      .then((resp) => {
        this.setProperties({
          moderator: true,
          can_grant_moderation: false,
          can_revoke_moderation: true,
          can_be_merged: resp.can_be_merged,
          can_be_anonymized: resp.can_be_anonymized,
        });
      })
      .catch(popupAjaxError);
  }

  disableSecondFactor() {
    return ajax(`/admin/users/${this.id}/disable_second_factor`, {
      type: "PUT",
    })
      .then(() => {
        this.set("second_factor_enabled", false);
      })
      .catch(popupAjaxError);
  }

  approve(approvedBy) {
    return ajax(`/admin/users/${this.id}/approve`, {
      type: "PUT",
    }).then(() => {
      this.setProperties({
        can_approve: false,
        approved: true,
        approved_by: approvedBy,
      });
    });
  }

  setOriginalTrustLevel() {
    this.set("originalTrustLevel", this.trust_level);
  }

  saveTrustLevel() {
    return ajax(`/admin/users/${this.id}/trust_level`, {
      type: "PUT",
      data: { level: this.trust_level },
    });
  }

  restoreTrustLevel() {
    this.set("trust_level", this.originalTrustLevel);
  }

  lockTrustLevel(locked) {
    return ajax(`/admin/users/${this.id}/trust_level_lock`, {
      type: "PUT",
      data: { locked: !!locked },
    });
  }

  @discourseComputed("suspended_till", "suspended_at")
  suspendDuration(suspendedTill, suspendedAt) {
    suspendedAt = moment(suspendedAt);
    suspendedTill = moment(suspendedTill);
    return suspendedAt.format("L") + " - " + suspendedTill.format("L");
  }

  suspend(data) {
    return ajax(`/admin/users/${this.id}/suspend`, {
      type: "PUT",
      data,
    }).then((result) => this.setProperties(result.suspension));
  }

  unsuspend() {
    return ajax(`/admin/users/${this.id}/unsuspend`, {
      type: "PUT",
    }).then((result) => this.setProperties(result.suspension));
  }

  logOut() {
    return ajax("/admin/users/" + this.id + "/log_out", {
      type: "POST",
      data: { username_or_email: this.username },
    });
  }

  impersonate() {
    return ajax("/admin/impersonate", {
      type: "POST",
      data: { username_or_email: this.username },
    });
  }

  activate() {
    return ajax(`/admin/users/${this.id}/activate`, {
      type: "PUT",
    });
  }

  deactivate() {
    return ajax(`/admin/users/${this.id}/deactivate`, {
      type: "PUT",
      data: { context: document.location.pathname },
    });
  }

  unsilence() {
    this.set("silencingUser", true);

    return ajax(`/admin/users/${this.id}/unsilence`, {
      type: "PUT",
    })
      .then((result) => {
        this.setProperties({
          silence_reason: result.unsilence.silence_reason,
          silenced_at: result.unsilence.silence_at,
          silenced_till: result.unsilence.silence_till,
        });
      })
      .finally(() => this.set("silencingUser", false));
  }

  silence(data) {
    this.set("silencingUser", true);

    return ajax(`/admin/users/${this.id}/silence`, {
      type: "PUT",
      data,
    })
      .then((result) => {
        this.setProperties({
          silence_reason: result.silence.silence_reason,
          silenced_at: result.silence.silenced_at,
          silenced_by: result.silence.silenced_by,
          silenced_till: result.silence.silenced_till,
        });
      })
      .finally(() => this.set("silencingUser", false));
  }

  sendActivationEmail() {
    return ajax(userPath("action/send_activation_email"), {
      type: "POST",
      data: { username: this.username },
    });
  }

  anonymize() {
    return ajax(`/admin/users/${this.id}/anonymize.json`, {
      type: "PUT",
    });
  }

  deleteAssociatedAccounts() {
    return ajax(`/admin/users/${this.id}/delete_associated_accounts`, {
      type: "PUT",
      data: {
        context: window.location.pathname,
      },
    }).then(() => {
      this.set("associated_accounts", []);
    });
  }

  destroy(formData) {
    return ajax(`/admin/users/${this.id}.json`, {
      type: "DELETE",
      data: formData,
    })
      .then((data) => {
        if (!data.deleted && data.user) {
          this.setProperties(data.user);
        }

        return data;
      })
      .catch(() => {
        this.find(this.id).then((u) => this.setProperties(u));
      });
  }

  merge(formData) {
    return ajax(`/admin/users/${this.id}/merge.json`, {
      type: "POST",
      data: formData,
    });
  }

  async loadDetails() {
    if (this.loadedDetails) {
      return this;
    }

    // we need to ask find to provide a raw object instead of AdminUser model because we're using
    // setProperties to update the values. Otherwise we would miss tracked properties which are not enumerable.
    const userProperties = await AdminUser.find(this.id, { raw: true });
    this.setProperties(userProperties);

    return this;
  }

  @discourseComputed("tl3_requirements")
  tl3Requirements(requirements) {
    if (requirements) {
      return this.store.createRecord("tl3Requirements", requirements);
    }
  }

  @discourseComputed("suspended_by")
  suspendedBy(user) {
    return user ? AdminUser.create(user) : null;
  }

  @discourseComputed("silenced_by")
  silencedBy(user) {
    return user ? AdminUser.create(user) : null;
  }

  @discourseComputed("approved_by")
  approvedBy(user) {
    return user ? AdminUser.create(user) : null;
  }

  deleteSSORecord() {
    return ajax(`/admin/users/${this.id}/sso_record.json`, {
      type: "DELETE",
    })
      .then(() => {
        this.set("single_sign_on_record", null);
      })
      .catch(popupAjaxError);
  }
}
