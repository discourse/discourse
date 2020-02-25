import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { alias, or, gt, not, and } from "@ember/object/computed";
import EmberObject from "@ember/object";
import { inject as service } from "@ember/service";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import User from "discourse/models/user";
import optionalService from "discourse/lib/optional-service";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { set, computed } from "@ember/object";

export default Controller.extend(CanCheckEmails, {
  indexStream: false,
  router: service(),
  userNotifications: inject("user-notifications"),
  currentPath: alias("router._router.currentPath"),
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

  @discourseComputed(
    "model.profile_hidden",
    "indexStream",
    "viewingSelf",
    "forceExpand"
  )
  collapsedInfo(profileHidden, indexStream, viewingSelf, forceExpand) {
    if (profileHidden) {
      return true;
    }
    return (!indexStream || viewingSelf) && !forceExpand;
  },
  canMuteOrIgnoreUser: or("model.can_ignore_user", "model.can_mute_user"),
  hasGivenFlags: gt("model.number_of_flags_given", 0),
  hasFlaggedPosts: gt("model.number_of_flagged_posts", 0),
  hasDeletedPosts: gt("model.number_of_deleted_posts", 0),
  hasBeenSuspended: gt("model.number_of_suspensions", 0),
  hasReceivedWarnings: gt("model.warnings_received_count", 0),

  showStaffCounters: or(
    "hasGivenFlags",
    "hasFlaggedPosts",
    "hasDeletedPosts",
    "hasBeenSuspended",
    "hasReceivedWarnings"
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
    return prioritizeNameInUx(name, this.siteSettings);
  },

  @discourseComputed("model.badge_count")
  showBadges(badgeCount) {
    return Discourse.SiteSettings.enable_badges && badgeCount > 0;
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
        .map(field => {
          set(field, "dasherized_name", field.get("name").dasherize());
          const value = userFields
            ? userFields[field.get("id").toString()]
            : null;
          return isEmpty(value) ? null : EmberObject.create({ value, field });
        })
        .compact();
    }
  },

  userNotificationLevel: computed(
    "currentUser.ignored_ids",
    "model.ignored",
    "model.muted",
    function() {
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
        action_name: "suspend_user"
      });
    },

    adminDelete() {
      this.adminTools.deleteUser(this.get("model.id"));
    },

    updateNotificationLevel(level) {
      const user = this.model;
      return user.updateNotificationLevel(level);
    }
  }
});
