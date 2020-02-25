import { notEmpty, and } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import { propertyNotEqual, setting } from "discourse/lib/computed";
import { userPath } from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";
import { fmt } from "discourse/lib/computed";
import { htmlSafe } from "@ember/template";

export default Controller.extend(CanCheckEmails, {
  adminTools: service(),
  originalPrimaryGroupId: null,
  customGroupIdsBuffer: null,
  availableGroups: null,
  userTitleValue: null,

  showBadges: setting("enable_badges"),
  hasLockedTrustLevel: notEmpty("model.manual_locked_trust_level"),

  primaryGroupDirty: propertyNotEqual(
    "originalPrimaryGroupId",
    "model.primary_group_id"
  ),

  canDisableSecondFactor: and(
    "model.second_factor_enabled",
    "model.can_disable_second_factor"
  ),

  @discourseComputed("model.customGroups")
  customGroupIds(customGroups) {
    return customGroups.mapBy("id");
  },

  @discourseComputed("customGroupIdsBuffer", "customGroupIds")
  customGroupsDirty(buffer, original) {
    if (buffer === null) return false;

    return buffer.length === original.length
      ? buffer.any(id => !original.includes(id))
      : true;
  },

  @discourseComputed("model.automaticGroups")
  automaticGroups(automaticGroups) {
    return automaticGroups
      .map(group => {
        const name = htmlSafe(group.name);
        return `<a href="/g/${name}">${name}</a>`;
      })
      .join(", ");
  },

  @discourseComputed("model.associated_accounts")
  associatedAccountsLoaded(associatedAccounts) {
    return typeof associatedAccounts !== "undefined";
  },

  @discourseComputed("model.associated_accounts")
  associatedAccounts(associatedAccounts) {
    return associatedAccounts
      .map(provider => `${provider.name} (${provider.description})`)
      .join(", ");
  },

  @discourseComputed("model.user_fields.[]")
  userFields(userFields) {
    return this.site.collectUserFields(userFields);
  },

  preferencesPath: fmt("model.username_lower", userPath("%@/preferences")),

  @discourseComputed(
    "model.can_delete_all_posts",
    "model.staff",
    "model.post_count"
  )
  deleteAllPostsExplanation(canDeleteAllPosts, staff, postCount) {
    if (canDeleteAllPosts) {
      return null;
    }

    if (staff) {
      return I18n.t("admin.user.delete_posts_forbidden_because_staff");
    }
    if (postCount > this.siteSettings.delete_all_posts_max) {
      return I18n.t("admin.user.cant_delete_all_too_many_posts", {
        count: this.siteSettings.delete_all_posts_max
      });
    } else {
      return I18n.t("admin.user.cant_delete_all_posts", {
        count: this.siteSettings.delete_user_max_post_age
      });
    }
  },

  @discourseComputed("model.canBeDeleted", "model.staff")
  deleteExplanation(canBeDeleted, staff) {
    if (canBeDeleted) {
      return null;
    }

    if (staff) {
      return I18n.t("admin.user.delete_forbidden_because_staff");
    } else {
      return I18n.t("admin.user.delete_forbidden", {
        count: this.siteSettings.delete_user_max_post_age
      });
    }
  },

  groupAdded(added) {
    this.model
      .groupAdded(added)
      .catch(() => bootbox.alert(I18n.t("generic_error")));
  },

  groupRemoved(groupId) {
    this.model
      .groupRemoved(groupId)
      .then(() => {
        if (groupId === this.originalPrimaryGroupId) {
          this.set("originalPrimaryGroupId", null);
        }
      })
      .catch(() => bootbox.alert(I18n.t("generic_error")));
  },

  actions: {
    impersonate() {
      return this.model.impersonate();
    },
    logOut() {
      return this.model.logOut();
    },
    resetBounceScore() {
      return this.model.resetBounceScore();
    },
    approve() {
      return this.model.approve(this.currentUser);
    },
    deactivate() {
      return this.model.deactivate();
    },
    sendActivationEmail() {
      return this.model.sendActivationEmail();
    },
    activate() {
      return this.model.activate();
    },
    revokeAdmin() {
      return this.model.revokeAdmin();
    },
    grantAdmin() {
      return this.model.grantAdmin();
    },
    revokeModeration() {
      return this.model.revokeModeration();
    },
    grantModeration() {
      return this.model.grantModeration();
    },
    saveTrustLevel() {
      return this.model.saveTrustLevel();
    },
    restoreTrustLevel() {
      return this.model.restoreTrustLevel();
    },
    lockTrustLevel(locked) {
      return this.model.lockTrustLevel(locked);
    },
    unsilence() {
      return this.model.unsilence();
    },
    silence() {
      return this.model.silence();
    },
    deleteAllPosts() {
      return this.model.deleteAllPosts();
    },
    anonymize() {
      return this.model.anonymize();
    },
    disableSecondFactor() {
      return this.model.disableSecondFactor();
    },

    clearPenaltyHistory() {
      const user = this.model;
      const path = `/admin/users/${user.get("id")}/penalty_history`;

      return ajax(path, { type: "DELETE" })
        .then(() => user.set("tl3_requirements.penalty_counts.total", 0))
        .catch(popupAjaxError);
    },

    destroy() {
      const postCount = this.get("model.post_count");
      if (postCount <= 5) {
        return this.model.destroy({ deletePosts: true });
      } else {
        return this.model.destroy();
      }
    },

    viewActionLogs() {
      this.adminTools.showActionLogs(this, {
        target_user: this.get("model.username")
      });
    },
    showSuspendModal() {
      this.adminTools.showSuspendModal(this.model);
    },
    unsuspend() {
      this.model.unsuspend().catch(popupAjaxError);
    },
    showSilenceModal() {
      this.adminTools.showSilenceModal(this.model);
    },

    saveUsername(newUsername) {
      const oldUsername = this.get("model.username");
      this.set("model.username", newUsername);

      const path = `/users/${oldUsername.toLowerCase()}/preferences/username`;

      return ajax(path, { data: { new_username: newUsername }, type: "PUT" })
        .catch(e => {
          this.set("model.username", oldUsername);
          popupAjaxError(e);
        })
        .finally(() => this.toggleProperty("editingUsername"));
    },

    saveName(newName) {
      const oldName = this.get("model.name");
      this.set("model.name", newName);

      const path = userPath(`${this.get("model.username").toLowerCase()}.json`);

      return ajax(path, { data: { name: newName }, type: "PUT" })
        .catch(e => {
          this.set("model.name", oldName);
          popupAjaxError(e);
        })
        .finally(() => this.toggleProperty("editingName"));
    },

    saveTitle(newTitle) {
      const oldTitle = this.get("model.title");
      this.set("model.title", newTitle);

      const path = userPath(`${this.get("model.username").toLowerCase()}.json`);

      return ajax(path, { data: { title: newTitle }, type: "PUT" })
        .catch(e => {
          this.set("model.title", oldTitle);
          popupAjaxError(e);
        })
        .finally(() => this.toggleProperty("editingTitle"));
    },

    saveCustomGroups() {
      const currentIds = this.customGroupIds;
      const bufferedIds = this.customGroupIdsBuffer;
      const availableGroups = this.availableGroups;

      bufferedIds
        .filter(id => !currentIds.includes(id))
        .forEach(id => this.groupAdded(availableGroups.findBy("id", id)));

      currentIds
        .filter(id => !bufferedIds.includes(id))
        .forEach(id => this.groupRemoved(id));
    },

    resetCustomGroups() {
      this.set("customGroupIdsBuffer", this.model.customGroups.mapBy("id"));
    },

    savePrimaryGroup() {
      const primaryGroupId = this.get("model.primary_group_id");
      const path = `/admin/users/${this.get("model.id")}/primary_group`;

      return ajax(path, {
        type: "PUT",
        data: { primary_group_id: primaryGroupId }
      })
        .then(() => this.set("originalPrimaryGroupId", primaryGroupId))
        .catch(() => bootbox.alert(I18n.t("generic_error")));
    },

    resetPrimaryGroup() {
      this.set("model.primary_group_id", this.originalPrimaryGroupId);
    }
  }
});
