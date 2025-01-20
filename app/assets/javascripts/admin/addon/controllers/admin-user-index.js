import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { alias, and, notEmpty } from "@ember/object/computed";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CanCheckEmailsHelper from "discourse/lib/can-check-emails-helper";
import { fmt, propertyNotEqual, setting } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { exportEntity } from "discourse/lib/export-csv";
import getURL from "discourse/lib/get-url";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import AdminUser from "admin/models/admin-user";
import DeletePostsConfirmationModal from "../components/modal/delete-posts-confirmation";
import DeleteUserPostsProgressModal from "../components/modal/delete-user-posts-progress";
import MergeUsersConfirmationModal from "../components/modal/merge-users-confirmation";
import MergeUsersProgressModal from "../components/modal/merge-users-progress";
import MergeUsersPromptModal from "../components/modal/merge-users-prompt";

export default class AdminUserIndexController extends Controller {
  @service router;
  @service dialog;
  @service adminTools;
  @service modal;

  originalPrimaryGroupId = null;
  customGroupIdsBuffer = null;
  availableGroups = null;
  userTitleValue = null;
  ssoExternalEmail = null;
  ssoLastPayload = null;

  @setting("enable_badges") showBadges;
  @setting("moderators_view_emails") canModeratorsViewEmails;
  @notEmpty("model.manual_locked_trust_level") hasLockedTrustLevel;

  @alias("site.site_contact_email_available") siteContactEmailAvailable;

  @propertyNotEqual("originalPrimaryGroupId", "model.primary_group_id")
  primaryGroupDirty;

  @and("model.second_factor_enabled", "model.can_disable_second_factor")
  canDisableSecondFactor;

  @fmt("model.username_lower", userPath("%@/preferences")) preferencesPath;

  @discourseComputed("model.customGroups")
  customGroupIds(customGroups) {
    return customGroups.mapBy("id");
  }

  @discourseComputed("customGroupIdsBuffer", "customGroupIds")
  customGroupsDirty(buffer, original) {
    if (buffer === null) {
      return false;
    }

    return buffer.length === original.length
      ? buffer.any((id) => !original.includes(id))
      : true;
  }

  @discourseComputed("model.automaticGroups")
  automaticGroups(automaticGroups) {
    return automaticGroups
      .map((group) => {
        const name = htmlSafe(group.name);
        return `<a href="/g/${name}">${name}</a>`;
      })
      .join(", ");
  }

  @discourseComputed("model.associated_accounts")
  associatedAccountsLoaded(associatedAccounts) {
    return typeof associatedAccounts !== "undefined";
  }

  @discourseComputed("model.associated_accounts")
  associatedAccounts(associatedAccounts) {
    return associatedAccounts
      ?.map((provider) => `${provider.name} (${provider.description})`)
      ?.join(", ");
  }

  @discourseComputed("model.user_fields.[]")
  userFields(userFields) {
    return this.site.collectUserFields(userFields);
  }

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
      return i18n("admin.user.delete_posts_forbidden_because_staff");
    }
    if (postCount > this.siteSettings.delete_all_posts_max) {
      return i18n("admin.user.cant_delete_all_too_many_posts", {
        count: this.siteSettings.delete_all_posts_max,
      });
    } else {
      return i18n("admin.user.cant_delete_all_posts", {
        count: this.siteSettings.delete_user_max_post_age,
      });
    }
  }

  @discourseComputed("model.canBeDeleted", "model.staff")
  deleteExplanation(canBeDeleted, staff) {
    if (canBeDeleted) {
      return null;
    }

    if (staff) {
      return i18n("admin.user.delete_forbidden_because_staff");
    } else {
      return i18n("admin.user.delete_forbidden", {
        count: this.siteSettings.delete_user_max_post_age,
      });
    }
  }

  @discourseComputed("model.username")
  postEditsByEditorFilter(username) {
    return { editor: username };
  }

  @computed("model.id", "currentUser.id")
  get canCheckEmails() {
    return new CanCheckEmailsHelper(
      this.model,
      this.canModeratorsViewEmails,
      this.currentUser
    ).canCheckEmails;
  }

  @computed("model.id", "currentUser.id")
  get canAdminCheckEmails() {
    return new CanCheckEmailsHelper(
      this.model,
      this.canModeratorsViewEmails,
      this.currentUser
    ).canAdminCheckEmails;
  }

  groupAdded(added) {
    this.model
      .groupAdded(added)
      .catch(() => this.dialog.alert(i18n("generic_error")));
  }

  groupRemoved(groupId) {
    this.model
      .groupRemoved(groupId)
      .then(() => {
        if (groupId === this.originalPrimaryGroupId) {
          this.set("originalPrimaryGroupId", null);
        }
      })
      .catch(() => this.dialog.alert(i18n("generic_error")));
  }

  @action
  sendArchiveToUser() {
    this.sendArchive(
      { send_to_user: true },
      i18n("admin.user.download_archive.confirm_user"),
      i18n("admin.user.download_archive.success_user")
    );
  }

  @action
  sendArchiveToAdmin() {
    this.sendArchive(
      { send_to_admin: true },
      i18n("admin.user.download_archive.confirm_admin"),
      i18n("admin.user.download_archive.success_admin")
    );
  }

  @action
  sendArchiveToSiteContact() {
    this.sendArchive(
      { send_to_site_contact: true },
      i18n("admin.user.download_archive.confirm_site_contact"),
      i18n("admin.user.download_archive.success_site_contact")
    );
  }

  sendArchive(args, confirmationMessage, successMessage) {
    args.export_user_id = this.model.id;

    this.dialog.yesNoConfirm({
      message: confirmationMessage,
      didConfirm: async () => {
        try {
          await exportEntity("user_archive", args);
          this.dialog.alert(successMessage);
        } catch (err) {
          popupAjaxError(err);
        }
      },
    });
  }

  @discourseComputed("ssoLastPayload")
  ssoPayload(lastPayload) {
    return lastPayload.split("&");
  }

  @action
  impersonate() {
    return this.model
      .impersonate()
      .then(() => DiscourseURL.redirectTo("/"))
      .catch((e) => {
        if (e.status === 404) {
          this.dialog.alert(i18n("admin.impersonate.not_found"));
        } else {
          this.dialog.alert(i18n("admin.impersonate.invalid"));
        }
      });
  }

  @action
  logOut() {
    return this.model
      .logOut()
      .then(() => this.dialog.alert(i18n("admin.user.logged_out")));
  }

  @action
  resetBounceScore() {
    return this.model.resetBounceScore();
  }

  @action
  approve() {
    return this.model.approve(this.currentUser);
  }

  @action
  _formatError(event) {
    return `http: ${event.status} - ${event.body}`;
  }

  @action
  deactivate() {
    return this.model
      .deactivate()
      .then(() =>
        this.model.setProperties({ active: false, can_activate: true })
      )
      .catch((e) => {
        const error = i18n("admin.user.deactivate_failed", {
          error: this._formatError(e),
        });
        this.dialog.alert(error);
      });
  }

  @action
  sendActivationEmail() {
    return this.model
      .sendActivationEmail()
      .then(() => this.dialog.alert(i18n("admin.user.activation_email_sent")))
      .catch(popupAjaxError);
  }

  @action
  activate() {
    return this.model
      .activate()
      .then(() =>
        this.model.setProperties({
          active: true,
          can_deactivate: !this.model.staff,
        })
      )
      .catch((e) => {
        const error = i18n("admin.user.activate_failed", {
          error: this._formatError(e),
        });
        this.dialog.alert(error);
      });
  }

  @action
  revokeAdmin() {
    return this.model.revokeAdmin();
  }

  @action
  grantAdmin() {
    return this.model
      .grantAdmin()
      .then((result) => {
        if (result.email_confirmation_required) {
          this.dialog.alert(i18n("admin.user.grant_admin_confirm"));
        }
      })
      .catch((error) => {
        const nonce = error.jqXHR?.responseJSON.second_factor_challenge_nonce;
        if (nonce) {
          this.router.transitionTo("second-factor-auth", {
            queryParams: { nonce },
          });
        } else {
          popupAjaxError(error);
        }
      });
  }

  @action
  revokeModeration() {
    return this.model.revokeModeration();
  }

  @action
  grantModeration() {
    return this.model.grantModeration();
  }

  @action
  saveTrustLevel() {
    return this.model
      .saveTrustLevel()
      .then(() => window.location.reload())
      .catch((e) => {
        let error;
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          error = e.jqXHR.responseJSON.errors[0];
        }
        error =
          error ||
          i18n("admin.user.trust_level_change_failed", {
            error: this._formatError(e),
          });
        this.dialog.alert(error);
      });
  }

  @action
  restoreTrustLevel() {
    return this.model.restoreTrustLevel();
  }

  @action
  lockTrustLevel(locked) {
    return this.model
      .lockTrustLevel(locked)
      .then(() => window.location.reload())
      .catch((e) => {
        let error;
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          error = e.jqXHR.responseJSON.errors[0];
        }
        error =
          error ||
          i18n("admin.user.trust_level_change_failed", {
            error: this._formatError(e),
          });
        this.dialog.alert(error);
      });
  }

  @action
  unsilence() {
    return this.model.unsilence();
  }

  @action
  silence() {
    return this.model.silence();
  }

  @action
  deleteAssociatedAccounts() {
    this.dialog.yesNoConfirm({
      message: i18n("admin.user.delete_associated_accounts_confirm"),
      didConfirm: () => {
        this.model.deleteAssociatedAccounts().catch(popupAjaxError);
      },
    });
  }

  @action
  anonymize() {
    const user = this.model;

    const performAnonymize = () => {
      this.model
        .anonymize()
        .then((data) => {
          if (data.success) {
            if (data.username) {
              document.location = getURL(
                `/admin/users/${user.get("id")}/${data.username}`
              );
            } else {
              document.location = getURL("/admin/users/list/active");
            }
          } else {
            this.dialog.alert(i18n("admin.user.anonymize_failed"));
            if (data.user) {
              user.setProperties(data.user);
            }
          }
        })
        .catch(() => this.dialog.alert(i18n("admin.user.anonymize_failed")));
    };

    this.dialog.alert({
      message: i18n("admin.user.anonymize_confirm"),
      class: "delete-user-modal",
      buttons: [
        {
          icon: "triangle-exclamation",
          label: i18n("admin.user.anonymize_yes"),
          class: "btn-danger",
          action: () => performAnonymize(),
        },
        {
          label: i18n("composer.cancel"),
        },
      ],
    });
  }

  @action
  disableSecondFactor() {
    this.dialog.yesNoConfirm({
      message: i18n("admin.user.disable_second_factor_confirm"),
      didConfirm: () => {
        return this.model.disableSecondFactor();
      },
    });
  }

  @action
  clearPenaltyHistory() {
    const user = this.model;
    const path = `/admin/users/${user.get("id")}/penalty_history`;

    return ajax(path, { type: "DELETE" })
      .then(() => user.set("tl3_requirements.penalty_counts.total", 0))
      .catch(popupAjaxError);
  }

  @action
  destroyUser() {
    const postCount = this.get("model.post_count");
    const maxPostCount = this.siteSettings.delete_all_posts_max;
    const location = document.location.pathname;

    const performDestroy = (block) => {
      this.dialog.notice(i18n("admin.user.deleting_user"));
      let formData = { context: location };
      if (block) {
        formData["block_email"] = true;
        formData["block_urls"] = true;
        formData["block_ip"] = true;
      }
      if (postCount <= maxPostCount) {
        formData["delete_posts"] = true;
      }
      this.model
        .destroy(formData)
        .then((data) => {
          if (data.deleted) {
            if (/^\/admin\/users\/list\//.test(location)) {
              document.location = location;
            } else {
              document.location = getURL("/admin/users/list/active");
            }
          } else {
            this.dialog.alert(i18n("admin.user.delete_failed"));
          }
        })
        .catch(() => {
          this.dialog.alert(i18n("admin.user.delete_failed"));
        });
    };

    this.dialog.alert({
      title: i18n("admin.user.delete_confirm_title"),
      message: i18n("admin.user.delete_confirm"),
      class: "delete-user-modal",
      buttons: [
        {
          label: i18n("admin.user.delete_dont_block"),
          class: "btn-primary",
          action: () => {
            return performDestroy(false);
          },
        },
        {
          icon: "triangle-exclamation",
          label: i18n("admin.user.delete_and_block"),
          class: "btn-danger",
          action: () => {
            return performDestroy(true);
          },
        },
        {
          label: i18n("composer.cancel"),
        },
      ],
    });
  }

  @action
  promptTargetUser() {
    this.modal.show(MergeUsersPromptModal, {
      model: {
        user: this.model,
        showMergeConfirmation: this.showMergeConfirmation,
      },
    });
  }

  @action
  showMergeConfirmation(targetUsername) {
    this.modal.show(MergeUsersConfirmationModal, {
      model: {
        username: this.model.username,
        targetUsername,
        merge: this.merge,
      },
    });
  }

  @action
  merge(targetUsername) {
    const user = this.model;
    const location = document.location.pathname;

    let formData = { context: location };

    if (targetUsername) {
      formData["target_username"] = targetUsername;
    }

    this.model
      .merge(formData)
      .then((response) => {
        if (response.success) {
          this.modal.show(MergeUsersProgressModal);
        } else {
          this.dialog.alert(i18n("admin.user.merge_failed"));
        }
      })
      .catch(() => {
        AdminUser.find(user.id).then((u) => user.setProperties(u));
        this.dialog.alert(i18n("admin.user.merge_failed"));
      });
  }

  @action
  viewActionLogs() {
    this.adminTools.showActionLogs(this, {
      target_user: this.get("model.username"),
    });
  }

  @action
  showSuspendModal() {
    this.adminTools.showSuspendModal(this.model);
  }

  @action
  unsuspend() {
    this.model.unsuspend().catch(popupAjaxError);
  }

  @action
  showSilenceModal() {
    this.adminTools.showSilenceModal(this.model);
  }

  @action
  saveUsername(newUsername) {
    const oldUsername = this.get("model.username");
    this.set("model.username", newUsername);

    const path = `/users/${oldUsername.toLowerCase()}/preferences/username`;

    return ajax(path, { data: { new_username: newUsername }, type: "PUT" })
      .catch((e) => {
        this.set("model.username", oldUsername);
        popupAjaxError(e);
      })
      .finally(() => this.toggleProperty("editingUsername"));
  }

  @action
  saveName(newName) {
    const oldName = this.get("model.name");
    this.set("model.name", newName);

    const path = userPath(`${this.get("model.username").toLowerCase()}.json`);

    return ajax(path, { data: { name: newName }, type: "PUT" })
      .catch((e) => {
        this.set("model.name", oldName);
        popupAjaxError(e);
      })
      .finally(() => this.toggleProperty("editingName"));
  }

  @action
  saveTitle(newTitle) {
    const oldTitle = this.get("model.title");
    this.set("model.title", newTitle);

    const path = userPath(`${this.get("model.username").toLowerCase()}.json`);

    return ajax(path, { data: { title: newTitle }, type: "PUT" })
      .catch((e) => {
        this.set("model.title", oldTitle);
        popupAjaxError(e);
      })
      .finally(() => this.toggleProperty("editingTitle"));
  }

  @action
  saveCustomGroups() {
    const currentIds = this.customGroupIds;
    const bufferedIds = this.customGroupIdsBuffer;
    const availableGroups = this.availableGroups;

    bufferedIds
      .filter((id) => !currentIds.includes(id))
      .forEach((id) => this.groupAdded(availableGroups.findBy("id", id)));

    currentIds
      .filter((id) => !bufferedIds.includes(id))
      .forEach((id) => this.groupRemoved(id));
  }

  @action
  resetCustomGroups() {
    this.set("customGroupIdsBuffer", this.model.customGroups.mapBy("id"));
  }

  @action
  savePrimaryGroup() {
    const primaryGroupId = this.get("model.primary_group_id");
    const path = `/admin/users/${this.get("model.id")}/primary_group`;

    return ajax(path, {
      type: "PUT",
      data: { primary_group_id: primaryGroupId },
    })
      .then(() => this.set("originalPrimaryGroupId", primaryGroupId))
      .catch(() => this.dialog.alert(i18n("generic_error")));
  }

  @action
  resetPrimaryGroup() {
    this.set("model.primary_group_id", this.originalPrimaryGroupId);
  }

  @action
  deleteSSORecord() {
    return this.dialog.yesNoConfirm({
      message: i18n("admin.user.discourse_connect.confirm_delete"),
      didConfirm: () => this.model.deleteSSORecord(),
    });
  }

  @action
  checkSsoEmail() {
    return ajax(userPath(`${this.model.username_lower}/sso-email.json`), {
      data: { context: window.location.pathname },
    }).then((result) => {
      if (result) {
        this.set("ssoExternalEmail", result.email);
      }
    });
  }

  @action
  checkSsoPayload() {
    return ajax(userPath(`${this.model.username_lower}/sso-payload.json`), {
      data: { context: window.location.pathname },
    }).then((result) => {
      if (result) {
        this.set("ssoLastPayload", result.payload);
      }
    });
  }

  @action
  showDeletePostsConfirmation() {
    this.modal.show(DeletePostsConfirmationModal, {
      model: { user: this.model, deleteAllPosts: this.deleteAllPosts },
    });
  }

  @action
  updateUserPostCount(count) {
    this.model.set("post_count", count);
  }

  @action
  deleteAllPosts() {
    this.modal.show(DeleteUserPostsProgressModal, {
      model: {
        user: this.model,
        updateUserPostCount: this.updateUserPostCount,
      },
    });
  }
}
