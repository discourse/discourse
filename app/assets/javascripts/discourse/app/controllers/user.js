import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action, computed, set } from "@ember/object";
import { and, equal, gt, not, or, readOnly } from "@ember/object/computed";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { isEmpty } from "@ember/utils";
import optionalService from "discourse/lib/optional-service";
import { prioritizeNameInUx } from "discourse/lib/settings";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class UserController extends Controller.extend(CanCheckEmails) {
  @service currentUser;
  @service router;
  @service dialog;
  @optionalService adminTools;

  @controller("user-notifications") userNotifications;

  @equal("router.currentRouteName", "user.summary") isSummaryRoute;
  @or("model.can_ignore_user", "model.can_mute_user") canMuteOrIgnoreUser;
  @gt("model.number_of_flags_given", 0) hasGivenFlags;
  @gt("model.number_of_flagged_posts", 0) hasFlaggedPosts;
  @gt("model.number_of_deleted_posts", 0) hasDeletedPosts;
  @gt("model.number_of_suspensions", 0) hasBeenSuspended;
  @gt("model.warnings_received_count", 0) hasReceivedWarnings;
  @gt("model.number_of_rejected_posts", 0) hasRejectedPosts;
  @equal("model.trust_level", 0) isTrustLevelZero;
  @or("isTrustLevelZero", "model.trust_level") hasTrustLevel;
  @or(
    "hasGivenFlags",
    "hasFlaggedPosts",
    "hasDeletedPosts",
    "hasBeenSuspended",
    "hasReceivedWarnings",
    "hasRejectedPosts"
  )
  showStaffCounters;
  @and(
    "model.featured_topic",
    "siteSettings.allow_featured_topic_on_user_profiles"
  )
  showFeaturedTopic;
  @not("model.isBasic") linkWebsite;
  @and("model.can_be_deleted", "model.can_delete_all_posts") canDeleteUser;
  @readOnly("router.currentRoute.parent.name") currentParentRoute;

  @discourseComputed("model.username")
  viewingSelf(username) {
    return this.currentUser && username === this.currentUser?.get("username");
  }

  @discourseComputed("viewingSelf", "model.profile_hidden")
  canExpandProfile(viewingSelf, profileHidden) {
    return !profileHidden && viewingSelf;
  }

  @discourseComputed("model.profileBackgroundUrl")
  hasProfileBackgroundUrl(background) {
    return !isEmpty(background.toString());
  }

  @discourseComputed(
    "model.profile_hidden",
    "isSummaryRoute",
    "viewingSelf",
    "forceExpand"
  )
  collapsedInfo(profileHidden, isSummaryRoute, viewingSelf, forceExpand) {
    if (profileHidden) {
      return true;
    }
    return (!isSummaryRoute || viewingSelf) && !forceExpand;
  }

  @computed("collapsedInfo")
  get collapsedInfoState() {
    return {
      isExpanded: !this.collapsedInfo,
      icon: this.collapsedInfo ? "angles-down" : "angles-up",
      label: this.collapsedInfo ? "expand_profile" : "collapse_profile",
      ariaLabel: this.collapsedInfo
        ? "user.sr_expand_profile"
        : "user.sr_collapse_profile",
      action: this.collapsedInfo ? "expandProfile" : "collapseProfile",
    };
  }

  @discourseComputed("model.suspended", "currentUser.staff")
  isNotSuspendedOrIsStaff(suspended, isStaff) {
    return !suspended || isStaff;
  }

  @discourseComputed("model.trust_level")
  removeNoFollow(trustLevel) {
    return trustLevel > 2 && !this.siteSettings.tl3_links_no_follow;
  }

  @discourseComputed("viewingSelf", "currentUser.admin")
  showBookmarks(viewingSelf, isAdmin) {
    return viewingSelf || isAdmin;
  }

  @discourseComputed("viewingSelf")
  showDrafts(viewingSelf) {
    return viewingSelf;
  }

  @discourseComputed("viewingSelf")
  showRead(viewingSelf) {
    return viewingSelf;
  }

  @discourseComputed(
    "viewingSelf",
    "currentUser.admin",
    "currentUser.can_send_private_messages"
  )
  showPrivateMessages(viewingSelf, isAdmin) {
    return (
      this.currentUser?.can_send_private_messages && (viewingSelf || isAdmin)
    );
  }

  @discourseComputed("viewingSelf", "currentUser.admin")
  showActivityTab(viewingSelf, isAdmin) {
    return viewingSelf || isAdmin || !this.siteSettings.hide_user_activity_tab;
  }

  @discourseComputed("viewingSelf", "currentUser.admin")
  showNotificationsTab(viewingSelf, isAdmin) {
    return viewingSelf || isAdmin;
  }

  @discourseComputed("model.name")
  nameFirst(name) {
    return prioritizeNameInUx(name);
  }

  @discourseComputed("model.badge_count")
  showBadges(badgeCount) {
    return this.siteSettings.enable_badges && badgeCount > 0;
  }

  @discourseComputed()
  canInviteToForum() {
    return this.currentUser?.get("can_invite_to_forum");
  }

  @discourseComputed("model.user_fields.@each.value")
  publicUserFields() {
    const siteUserFields = this.site.get("user_fields");
    if (!isEmpty(siteUserFields)) {
      const userFields = this.get("model.user_fields");
      return siteUserFields
        .filterBy("show_on_profile", true)
        .sortBy("position")
        .map((field) => {
          set(field, "dasherized_name", dasherize(field.get("name")));
          const value = userFields
            ? userFields[field.get("id").toString()]
            : null;
          return isEmpty(value) ? null : EmberObject.create({ value, field });
        })
        .compact();
    }
  }

  @discourseComputed("model.primary_group_name")
  primaryGroup(group) {
    if (group) {
      return `group-${group}`;
    }
  }

  @computed("currentUser.ignored_ids", "model.ignored", "model.muted")
  get userNotificationLevel() {
    if (this.get("model.ignored")) {
      return "changeToIgnored";
    } else if (this.get("model.muted")) {
      return "changeToMuted";
    } else {
      return "changeToNormal";
    }
  }

  set userNotificationLevel(value) {
    /* noop */
  }

  get displayTopLevelAdminButton() {
    if (!this.currentUser?.staff) {
      return false;
    }

    return this.site.desktopView;
  }

  @action
  showSuspensions(event) {
    event?.preventDefault();
    this.adminTools.showActionLogs(this, {
      target_user: this.get("model.username"),
      action_name: "suspend_user",
    });
  }

  @action
  collapseProfile() {
    this.set("forceExpand", false);
  }

  @action
  expandProfile() {
    this.set("forceExpand", true);
  }

  @action
  adminDelete() {
    const userId = this.get("model.id");
    const location = document.location.pathname;

    const performDestroy = (block) => {
      this.dialog.notice(I18n.t("admin.user.deleting_user"));
      let formData = { context: location };
      if (block) {
        formData["block_email"] = true;
        formData["block_urls"] = true;
        formData["block_ip"] = true;
      }
      formData["delete_posts"] = true;

      return this.adminTools
        .deleteUser(userId, formData)
        .then((data) => {
          if (data.deleted) {
            document.location = getURL("/admin/users/list/active");
          } else {
            this.dialog.alert(I18n.t("admin.user.delete_failed"));
          }
        })
        .catch(() => this.dialog.alert(I18n.t("admin.user.delete_failed")));
    };

    this.dialog.alert({
      title: I18n.t("admin.user.delete_confirm_title"),
      message: I18n.t("admin.user.delete_confirm"),
      class: "delete-user-modal",
      buttons: [
        {
          label: I18n.t("admin.user.delete_dont_block"),
          class: "btn-primary",
          action: () => {
            return performDestroy(false);
          },
        },
        {
          icon: "triangle-exclamation",
          label: I18n.t("admin.user.delete_and_block"),
          class: "btn-danger",
          action: () => {
            return performDestroy(true);
          },
        },
        {
          label: I18n.t("composer.cancel"),
        },
      ],
    });
  }

  @action
  updateNotificationLevel(params) {
    return this.model.updateNotificationLevel(params);
  }
}
