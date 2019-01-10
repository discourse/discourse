import CanCheckEmails from "discourse/mixins/can-check-emails";
import computed from "ember-addons/ember-computed-decorators";
import User from "discourse/models/user";
import optionalService from "discourse/lib/optional-service";

export default Ember.Controller.extend(CanCheckEmails, {
  indexStream: false,
  application: Ember.inject.controller(),
  userNotifications: Ember.inject.controller("user-notifications"),
  currentPath: Ember.computed.alias("application.currentPath"),
  adminTools: optionalService(),

  @computed("model.username")
  viewingSelf(username) {
    let currentUser = this.currentUser;
    return currentUser && username === currentUser.get("username");
  },

  @computed("viewingSelf", "model.profile_hidden")
  canExpandProfile(viewingSelf, profileHidden) {
    return !profileHidden && viewingSelf;
  },

  @computed("model.profileBackground")
  hasProfileBackground(background) {
    return !Ember.isEmpty(background.toString());
  },

  @computed("model.profile_hidden", "indexStream", "viewingSelf", "forceExpand")
  collapsedInfo(profileHidden, indexStream, viewingSelf, forceExpand) {
    if (profileHidden) {
      return true;
    }
    return (!indexStream || viewingSelf) && !forceExpand;
  },

  hasGivenFlags: Ember.computed.gt("model.number_of_flags_given", 0),
  hasFlaggedPosts: Ember.computed.gt("model.number_of_flagged_posts", 0),
  hasDeletedPosts: Ember.computed.gt("model.number_of_deleted_posts", 0),
  hasBeenSuspended: Ember.computed.gt("model.number_of_suspensions", 0),
  hasReceivedWarnings: Ember.computed.gt("model.warnings_received_count", 0),

  showStaffCounters: Ember.computed.or(
    "hasGivenFlags",
    "hasFlaggedPosts",
    "hasDeletedPosts",
    "hasBeenSuspended",
    "hasReceivedWarnings"
  ),

  @computed("model.suspended", "currentUser.staff")
  isNotSuspendedOrIsStaff(suspended, isStaff) {
    return !suspended || isStaff;
  },

  linkWebsite: Ember.computed.not("model.isBasic"),

  @computed("model.trust_level")
  removeNoFollow(trustLevel) {
    return trustLevel > 2 && !this.siteSettings.tl3_links_no_follow;
  },

  @computed("viewingSelf", "currentUser.admin")
  showBookmarks(viewingSelf, isAdmin) {
    return viewingSelf || isAdmin;
  },

  @computed("viewingSelf")
  showDrafts(viewingSelf) {
    return viewingSelf;
  },

  @computed("viewingSelf", "currentUser.admin")
  showPrivateMessages(viewingSelf, isAdmin) {
    return (
      this.siteSettings.enable_personal_messages && (viewingSelf || isAdmin)
    );
  },

  @computed("viewingSelf", "currentUser.staff")
  showNotificationsTab(viewingSelf, staff) {
    return viewingSelf || staff;
  },

  @computed("model.name")
  nameFirst(name) {
    return (
      !this.get("siteSettings.prioritize_username_in_ux") &&
      name &&
      name.trim().length > 0
    );
  },

  @computed("model.badge_count")
  showBadges(badgeCount) {
    return Discourse.SiteSettings.enable_badges && badgeCount > 0;
  },

  @computed()
  canInviteToForum() {
    return User.currentProp("can_invite_to_forum");
  },

  canDeleteUser: Ember.computed.and(
    "model.can_be_deleted",
    "model.can_delete_all_posts"
  ),

  @computed("model.user_fields.@each.value")
  publicUserFields() {
    const siteUserFields = this.site.get("user_fields");
    if (!Ember.isEmpty(siteUserFields)) {
      const userFields = this.get("model.user_fields");
      return siteUserFields
        .filterBy("show_on_profile", true)
        .sortBy("position")
        .map(field => {
          Ember.set(field, "dasherized_name", field.get("name").dasherize());
          const value = userFields
            ? userFields[field.get("id").toString()]
            : null;
          return Ember.isEmpty(value)
            ? null
            : Ember.Object.create({ value, field });
        })
        .compact();
    }
  },

  actions: {
    collapseProfile() {
      this.set("forceExpand", false);
    },

    expandProfile() {
      this.set("forceExpand", true);
    },

    showSuspensions() {
      this.get("adminTools").showActionLogs(this, {
        target_user: this.get("model.username"),
        action_name: "suspend_user"
      });
    },

    adminDelete() {
      this.get("adminTools").deleteUser(this.get("model.id"));
    }
  }
});
