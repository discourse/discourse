import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { computed, set } from "@ember/object";
import { and, equal, gt, not, or } from "@ember/object/computed";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import User from "discourse/models/user";
import I18n from "I18n";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";
import { isEmpty } from "@ember/utils";
import optionalService from "discourse/lib/optional-service";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { inject as service } from "@ember/service";

export default Controller.extend(CanCheckEmails, {
  router: service(),
  userNotifications: controller("user-notifications"),
  adminTools: optionalService(),

  @discourseComputed("model.username")
  viewingSelf(username) {
    let currentUser = this.currentUser;
    return currentUser && username === currentUser.get("username");
  },

  @discourseComputed("viewingSelf", "model.profile_hidden")
  canExpandProfile(viewingSelf, profileHidden) {
    return !profileHidden && viewingSelf;
  },

  @discourseComputed("model.profileBackgroundUrl")
  hasProfileBackgroundUrl(background) {
    return !isEmpty(background.toString());
  },

  isSummaryRoute: equal("router.currentRouteName", "user.summary"),

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
  },
  canMuteOrIgnoreUser: or("model.can_ignore_user", "model.can_mute_user"),
  hasGivenFlags: gt("model.number_of_flags_given", 0),
  hasFlaggedPosts: gt("model.number_of_flagged_posts", 0),
  hasDeletedPosts: gt("model.number_of_deleted_posts", 0),
  hasBeenSuspended: gt("model.number_of_suspensions", 0),
  hasReceivedWarnings: gt("model.warnings_received_count", 0),
  hasRejectedPosts: gt("model.number_of_rejected_posts", 0),

  collapsedInfoState: computed("collapsedInfo", function () {
    return {
      isExpanded: !this.collapsedInfo,
      icon: this.collapsedInfo ? "angle-double-down" : "angle-double-up",
      label: this.collapsedInfo ? "expand_profile" : "collapse_profile",
      action: this.collapsedInfo ? "expandProfile" : "collapseProfile",
    };
  }),

  showStaffCounters: or(
    "hasGivenFlags",
    "hasFlaggedPosts",
    "hasDeletedPosts",
    "hasBeenSuspended",
    "hasReceivedWarnings",
    "hasRejectedPosts"
  ),

  showFeaturedTopic: and(
    "model.featured_topic",
    "siteSettings.allow_featured_topic_on_user_profiles"
  ),

  @discourseComputed("model.suspended", "currentUser.staff")
  isNotSuspendedOrIsStaff(suspended, isStaff) {
    return !suspended || isStaff;
  },

  linkWebsite: not("model.isBasic"),

  @discourseComputed("model.trust_level")
  removeNoFollow(trustLevel) {
    return trustLevel > 2 && !this.siteSettings.tl3_links_no_follow;
  },

  @discourseComputed("viewingSelf", "currentUser.admin")
  showBookmarks(viewingSelf, isAdmin) {
    return viewingSelf || isAdmin;
  },

  @discourseComputed("viewingSelf")
  showDrafts(viewingSelf) {
    return viewingSelf;
  },

  @discourseComputed("viewingSelf")
  showRead(viewingSelf) {
    return viewingSelf;
  },

  @discourseComputed("viewingSelf", "currentUser.admin")
  showPrivateMessages(viewingSelf, isAdmin) {
    return (
      this.siteSettings.enable_personal_messages && (viewingSelf || isAdmin)
    );
  },

  @discourseComputed("viewingSelf", "currentUser.staff")
  showNotificationsTab(viewingSelf, staff) {
    return viewingSelf || staff;
  },

  @discourseComputed("model.name")
  nameFirst(name) {
    return prioritizeNameInUx(name);
  },

  @discourseComputed("model.badge_count")
  showBadges(badgeCount) {
    return this.siteSettings.enable_badges && badgeCount > 0;
  },

  @discourseComputed()
  canInviteToForum() {
    return User.currentProp("can_invite_to_forum");
  },

  canDeleteUser: and("model.can_be_deleted", "model.can_delete_all_posts"),

  @discourseComputed("model.user_fields.@each.value")
  publicUserFields() {
    const siteUserFields = this.site.get("user_fields");
    if (!isEmpty(siteUserFields)) {
      const userFields = this.get("model.user_fields");
      return siteUserFields
        .filterBy("show_on_profile", true)
        .sortBy("position")
        .map((field) => {
          set(field, "dasherized_name", field.get("name").dasherize());
          const value = userFields
            ? userFields[field.get("id").toString()]
            : null;
          return isEmpty(value) ? null : EmberObject.create({ value, field });
        })
        .compact();
    }
  },

  @discourseComputed("model.primary_group_name")
  primaryGroup(group) {
    if (group) {
      return `group-${group}`;
    }
  },

  userNotificationLevel: computed(
    "currentUser.ignored_ids",
    "model.ignored",
    "model.muted",
    function () {
      if (this.get("model.ignored")) {
        return "changeToIgnored";
      } else if (this.get("model.muted")) {
        return "changeToMuted";
      } else {
        return "changeToNormal";
      }
    }
  ),

  actions: {
    collapseProfile() {
      this.set("forceExpand", false);
    },

    expandProfile() {
      this.set("forceExpand", true);
    },

    showSuspensions() {
      this.adminTools.showActionLogs(this, {
        target_user: this.get("model.username"),
        action_name: "suspend_user",
      });
    },

    adminDelete() {
      const userId = this.get("model.id");
      const message = I18n.t("admin.user.delete_confirm");
      const location = document.location.pathname;

      const performDestroy = (block) => {
        bootbox.dialog(I18n.t("admin.user.deleting_user"));
        let formData = { context: location };
        if (block) {
          formData["block_email"] = true;
          formData["block_urls"] = true;
          formData["block_ip"] = true;
        }
        formData["delete_posts"] = true;

        this.adminTools
          .deleteUser(userId, formData)
          .then((data) => {
            if (data.deleted) {
              document.location = getURL("/admin/users/list/active");
            } else {
              bootbox.alert(I18n.t("admin.user.delete_failed"));
            }
          })
          .catch(() => bootbox.alert(I18n.t("admin.user.delete_failed")));
      };

      const buttons = [
        {
          label: I18n.t("composer.cancel"),
          class: "btn",
          link: true,
        },
        {
          label:
            `${iconHTML("exclamation-triangle")} ` +
            I18n.t("admin.user.delete_and_block"),
          class: "btn btn-danger",
          callback: function () {
            performDestroy(true);
          },
        },
        {
          label: I18n.t("admin.user.delete_dont_block"),
          class: "btn btn-primary",
          callback: function () {
            performDestroy(false);
          },
        },
      ];

      bootbox.dialog(message, buttons, { classes: "delete-user-modal" });
    },

    updateNotificationLevel(level) {
      const user = this.model;
      return user.updateNotificationLevel(level);
    },
  },
});
