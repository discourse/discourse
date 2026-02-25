import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action, computed, set } from "@ember/object";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { compare, isEmpty } from "@ember/utils";
import CanCheckEmailsHelper from "discourse/lib/can-check-emails-helper";
import getURL from "discourse/lib/get-url";
import optionalService from "discourse/lib/optional-service";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { i18n } from "discourse-i18n";

export default class UserController extends Controller {
  @service currentUser;
  @service router;
  @service dialog;
  @optionalService adminTools;

  @controller("user-notifications") userNotifications;

  @computed("siteSettings.moderators_view_emails")
  get canModeratorsViewEmails() {
    return this.siteSettings.moderators_view_emails;
  }

  @computed("router.currentRouteName")
  get isSummaryRoute() {
    return this.router?.currentRouteName === "user.summary";
  }

  @computed("model.can_ignore_user", "model.can_mute_user")
  get canMuteOrIgnoreUser() {
    return this.model?.can_ignore_user || this.model?.can_mute_user;
  }

  @computed("model.number_of_flags_given")
  get hasGivenFlags() {
    return this.model?.number_of_flags_given > 0;
  }

  @computed("model.number_of_flags")
  get hasFlags() {
    return this.model?.number_of_flags > 0;
  }

  @computed("model.number_of_deleted_posts")
  get hasDeletedPosts() {
    return this.model?.number_of_deleted_posts > 0;
  }

  @computed("model.number_of_silencings")
  get hasBeenSilenced() {
    return this.model?.number_of_silencings > 0;
  }

  @computed("model.number_of_suspensions")
  get hasBeenSuspended() {
    return this.model?.number_of_suspensions > 0;
  }

  @computed("model.warnings_received_count")
  get hasReceivedWarnings() {
    return this.model?.warnings_received_count > 0;
  }

  @computed("model.number_of_rejected_posts")
  get hasRejectedPosts() {
    return this.model?.number_of_rejected_posts > 0;
  }

  @computed("model.trust_level")
  get isTrustLevelZero() {
    return this.model?.trust_level === 0;
  }

  @computed("isTrustLevelZero", "model.trust_level")
  get hasTrustLevel() {
    return this.isTrustLevelZero || this.model?.trust_level;
  }

  @computed(
    "hasGivenFlags",
    "hasFlags",
    "hasDeletedPosts",
    "hasBeenSilenced",
    "hasBeenSuspended",
    "hasReceivedWarnings",
    "hasRejectedPosts"
  )
  get showStaffCounters() {
    return (
      this.hasGivenFlags ||
      this.hasFlags ||
      this.hasDeletedPosts ||
      this.hasBeenSilenced ||
      this.hasBeenSuspended ||
      this.hasReceivedWarnings ||
      this.hasRejectedPosts
    );
  }

  @computed(
    "model.featured_topic",
    "siteSettings.allow_featured_topic_on_user_profiles"
  )
  get showFeaturedTopic() {
    return (
      this.model?.featured_topic &&
      this.siteSettings?.allow_featured_topic_on_user_profiles
    );
  }

  @computed("model.isBasic")
  get linkWebsite() {
    return !this.model?.isBasic;
  }

  @computed("model.can_be_deleted", "model.can_delete_all_posts")
  get canDeleteUser() {
    return this.model?.can_be_deleted && this.model?.can_delete_all_posts;
  }

  @computed("router.currentRoute.parent.name")
  get currentParentRoute() {
    return this.router?.currentRoute?.parent?.name;
  }

  @computed("model.username")
  get viewingSelf() {
    return (
      this.currentUser &&
      this.model?.username === this.currentUser?.get("username")
    );
  }

  @computed("viewingSelf", "model.profile_hidden")
  get canExpandProfile() {
    return !this.model?.profile_hidden && this.viewingSelf;
  }

  @computed("model.profileBackgroundUrl")
  get hasProfileBackgroundUrl() {
    return !isEmpty(this.model?.profileBackgroundUrl?.toString());
  }

  @computed(
    "model.profile_hidden",
    "isSummaryRoute",
    "viewingSelf",
    "forceExpand"
  )
  get collapsedInfo() {
    if (this.model?.profile_hidden) {
      return true;
    }
    return (!this.isSummaryRoute || this.viewingSelf) && !this.forceExpand;
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
      action: this.toggleProfile,
    };
  }

  @computed("model.suspended", "model.silenced", "currentUser.staff")
  get isNotRestrictedOrIsStaff() {
    return (
      (!this.model?.suspended && !this.model?.silenced) ||
      this.currentUser?.staff
    );
  }

  @computed("model.trust_level")
  get removeNoFollow() {
    return (
      this.model?.trust_level > 2 && !this.siteSettings.tl3_links_no_follow
    );
  }

  @computed("viewingSelf", "currentUser.admin")
  get showBookmarks() {
    return this.viewingSelf || this.currentUser?.admin;
  }

  @computed("viewingSelf")
  get showDrafts() {
    return this.viewingSelf;
  }

  @computed("viewingSelf")
  get showRead() {
    return this.viewingSelf;
  }

  @computed(
    "viewingSelf",
    "currentUser.admin",
    "currentUser.can_send_private_messages"
  )
  get showPrivateMessages() {
    return (
      this.currentUser?.can_send_private_messages &&
      (this.viewingSelf || this.currentUser?.admin)
    );
  }

  @computed("viewingSelf", "currentUser.admin")
  get showActivityTab() {
    return (
      this.viewingSelf ||
      this.currentUser?.admin ||
      !this.siteSettings.hide_user_activity_tab
    );
  }

  @computed("viewingSelf", "currentUser.admin")
  get showNotificationsTab() {
    return this.viewingSelf || this.currentUser?.admin;
  }

  @computed("model.name")
  get nameFirst() {
    return prioritizeNameInUx(this.model?.name);
  }

  @computed("model.badge_count")
  get showBadges() {
    return this.siteSettings.enable_badges && this.model?.badge_count > 0;
  }

  @computed()
  get canInviteToForum() {
    return this.currentUser?.get("can_invite_to_forum");
  }

  @computed("model.user_fields.@each.value")
  get publicUserFields() {
    const siteUserFields = this.site.get("user_fields");
    if (!isEmpty(siteUserFields)) {
      const userFields = this.get("model.user_fields");
      return siteUserFields
        .filter((field) => field.show_on_profile)
        .sort((a, b) => compare(a?.position, b?.position))
        .map((field) => {
          set(field, "dasherized_name", dasherize(field.get("name")));
          const value = userFields
            ? userFields[field.get("id").toString()]
            : null;
          return isEmpty(value) ? null : EmberObject.create({ value, field });
        })
        .filter((item) => item != null);
    }
  }

  @computed("model.primary_group_name")
  get primaryGroup() {
    if (this.model?.primary_group_name) {
      return `group-${this.model?.primary_group_name}`;
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

  @computed("model.id", "currentUser.id")
  get canCheckEmails() {
    return new CanCheckEmailsHelper(
      this.model.id,
      this.canModeratorsViewEmails,
      this.currentUser
    ).canCheckEmails;
  }

  get displayTopLevelAdminButton() {
    if (!this.currentUser?.staff) {
      return false;
    }

    return this.site.desktopView;
  }

  get silencingsRouteQuery() {
    return {
      filters: {
        target_user: this.get("model.username"),
        action_name: "silence_user",
      },
    };
  }

  get suspensionsRouteQuery() {
    return {
      filters: {
        target_user: this.get("model.username"),
        action_name: "suspend_user",
      },
    };
  }

  @action
  toggleProfile() {
    this.toggleProperty("forceExpand");
  }

  @action
  adminDelete() {
    const userId = this.get("model.id");
    const location = document.location.pathname;

    const performDestroy = (block) => {
      this.dialog.notice(i18n("admin.user.deleting_user"));
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
            this.dialog.alert(i18n("admin.user.delete_failed"));
          }
        })
        .catch(() => this.dialog.alert(i18n("admin.user.delete_failed")));
    };

    this.dialog.alert({
      title: i18n("admin.user.delete_confirm_title"),
      message: i18n("admin.user.delete_confirm"),
      class: "delete-user-modal",
      buttons: [
        {
          label: i18n("admin.user.delete_dont_block"),
          class: "btn-danger delete-dont-block",
          action: () => {
            return performDestroy(false);
          },
        },
        {
          icon: "triangle-exclamation",
          label: i18n("admin.user.delete_and_block"),
          class: "btn-danger delete-and-block",
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
  updateNotificationLevel(params) {
    return this.model.updateNotificationLevel(params);
  }
}
