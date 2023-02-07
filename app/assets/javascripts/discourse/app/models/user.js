import EmberObject, { computed, get, getProperties } from "@ember/object";
import { camelize } from "@ember/string";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { defaultHomepage, escapeExpression } from "discourse/lib/utilities";
import {
  alias,
  equal,
  filterBy,
  gt,
  mapBy,
  or,
  readOnly,
} from "@ember/object/computed";
import getURL, { getURLWithCDN } from "discourse-common/lib/get-url";
import { A } from "@ember/array";
import Badge from "discourse/models/badge";
import Bookmark from "discourse/models/bookmark";
import Category from "discourse/models/category";
import Group from "discourse/models/group";
import I18n from "I18n";
import { NotificationLevels } from "discourse/lib/notification-levels";
import PreloadStore from "discourse/lib/preload-store";
import { Promise } from "rsvp";
import RestModel from "discourse/models/rest";
import Singleton from "discourse/mixins/singleton";
import Site from "discourse/models/site";
import UserAction from "discourse/models/user-action";
import UserActionStat from "discourse/models/user-action-stat";
import UserBadge from "discourse/models/user-badge";
import UserDraftsStream from "discourse/models/user-drafts-stream";
import UserPostsStream from "discourse/models/user-posts-stream";
import UserStream from "discourse/models/user-stream";
import { ajax } from "discourse/lib/ajax";
import deprecated from "discourse-common/lib/deprecated";
import discourseComputed from "discourse-common/utils/decorators";
import { emojiUnescape } from "discourse/lib/text";
import { getOwner } from "discourse-common/lib/get-owner";
import { isEmpty } from "@ember/utils";
import { longDate } from "discourse/lib/formatter";
import { url } from "discourse/lib/computed";
import { userPath } from "discourse/lib/url";
import { htmlSafe } from "@ember/template";
import Evented from "@ember/object/evented";
import { cancel } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";
import { isTesting } from "discourse-common/config/environment";
import {
  hideAllUserTips,
  hideUserTip,
  showNextUserTip,
  showUserTip,
} from "discourse/lib/user-tips";
import { dependentKeyCompat } from "@ember/object/compat";

export const SECOND_FACTOR_METHODS = {
  TOTP: 1,
  BACKUP_CODE: 2,
  SECURITY_KEY: 3,
};

const TEXT_SIZE_COOKIE_NAME = "text_size";
const COOKIE_EXPIRY_DAYS = 365;

export function extendTextSizeCookie() {
  const currentValue = cookie(TEXT_SIZE_COOKIE_NAME);
  if (currentValue) {
    cookie(TEXT_SIZE_COOKIE_NAME, currentValue, {
      path: "/",
      expires: COOKIE_EXPIRY_DAYS,
    });
  }
}

const isForever = (dt) => moment().diff(dt, "years") < -100;

let userFields = [
  "bio_raw",
  "website",
  "location",
  "name",
  "title",
  "locale",
  "custom_fields",
  "user_fields",
  "muted_usernames",
  "ignored_usernames",
  "allowed_pm_usernames",
  "profile_background_upload_url",
  "card_background_upload_url",
  "muted_tags",
  "tracked_tags",
  "watched_tags",
  "watching_first_post_tags",
  "date_of_birth",
  "primary_group_id",
  "flair_group_id",
  "user_notification_schedule",
  "sidebar_category_ids",
  "sidebar_tag_names",
  "status",
];

export function addSaveableUserField(fieldName) {
  userFields.push(fieldName);
}

let userOptionFields = [
  "mailing_list_mode",
  "mailing_list_mode_frequency",
  "external_links_in_new_tab",
  "email_digests",
  "email_in_reply_to",
  "email_messages_level",
  "email_level",
  "email_previous_replies",
  "color_scheme_id",
  "dark_scheme_id",
  "dynamic_favicon",
  "enable_quoting",
  "enable_defer",
  "automatically_unpin_topics",
  "digest_after_minutes",
  "new_topic_duration_minutes",
  "auto_track_topics_after_msecs",
  "notification_level_when_replying",
  "like_notification_frequency",
  "include_tl0_in_digests",
  "theme_ids",
  "allow_private_messages",
  "enable_allowed_pm_users",
  "homepage_id",
  "hide_profile_and_presence",
  "text_size",
  "title_count_mode",
  "timezone",
  "skip_new_user_tips",
  "seen_popups",
  "default_calendar",
  "bookmark_auto_delete_preference",
  "sidebar_list_destination",
];

export function addSaveableUserOptionField(fieldName) {
  userOptionFields.push(fieldName);
}

function userOption(userOptionKey) {
  return computed(`user_option.${userOptionKey}`, {
    get(key) {
      deprecated(
        `Getting ${key} property of user object is deprecated. Use user_option object instead`,
        {
          id: "discourse.user.userOptions",
          since: "2.9.0.beta12",
          dropFrom: "3.0.0.beta1",
        }
      );

      return this.get(`user_option.${key}`);
    },

    set(key, value) {
      deprecated(
        `Setting ${key} property of user object is deprecated. Use user_option object instead`,
        {
          id: "discourse.user.userOptions",
          since: "2.9.0.beta12",
          dropFrom: "3.0.0.beta1",
        }
      );

      if (!this.user_option) {
        this.set("user_option", {});
      }

      return this.set(`user_option.${key}`, value);
    },
  });
}

const User = RestModel.extend({
  mailing_list_mode: userOption("mailing_list_mode"),
  external_links_in_new_tab: userOption("external_links_in_new_tab"),
  enable_quoting: userOption("enable_quoting"),
  dynamic_favicon: userOption("dynamic_favicon"),
  automatically_unpin_topics: userOption("automatically_unpin_topics"),
  likes_notifications_disabled: userOption("likes_notifications_disabled"),
  hide_profile_and_presence: userOption("hide_profile_and_presence"),
  title_count_mode: userOption("title_count_mode"),
  enable_defer: userOption("enable_defer"),
  timezone: userOption("timezone"),
  skip_new_user_tips: userOption("skip_new_user_tips"),
  default_calendar: userOption("default_calendar"),
  bookmark_auto_delete_preference: userOption(
    "bookmark_auto_delete_preference"
  ),
  seen_popups: userOption("seen_popups"),
  should_be_redirected_to_top: userOption("should_be_redirected_to_top"),
  redirected_to_top: userOption("redirected_to_top"),
  treat_as_new_topic_start_date: userOption("treat_as_new_topic_start_date"),

  hasPMs: gt("private_messages_stats.all", 0),
  hasStartedPMs: gt("private_messages_stats.mine", 0),
  hasUnreadPMs: gt("private_messages_stats.unread", 0),

  @discourseComputed("can_be_deleted", "post_count")
  canBeDeleted(canBeDeleted, postCount) {
    const maxPostCount = this.siteSettings.delete_all_posts_max;
    return canBeDeleted && postCount <= maxPostCount;
  },

  @discourseComputed()
  stream() {
    return UserStream.create({ user: this });
  },

  @discourseComputed()
  bookmarks() {
    return Bookmark.create({ user: this });
  },

  @discourseComputed()
  postsStream() {
    return UserPostsStream.create({ user: this });
  },

  @discourseComputed()
  userDraftsStream() {
    return UserDraftsStream.create({ user: this });
  },

  staff: computed("admin", "moderator", {
    get() {
      return this.admin || this.moderator;
    },

    // prevents staff property to be overridden
    set() {
      return this.admin || this.moderator;
    },
  }),

  destroySession() {
    return ajax(`/session/${this.username}`, { type: "DELETE" });
  },

  @discourseComputed("username_lower")
  searchContext(username) {
    return {
      type: "user",
      id: username,
      user: this,
    };
  },

  @discourseComputed("username", "name")
  displayName(username, name) {
    if (this.siteSettings.enable_names && !isEmpty(name)) {
      return name;
    }
    return username;
  },

  @discourseComputed("profile_background_upload_url")
  profileBackgroundUrl(bgUrl) {
    if (isEmpty(bgUrl) || !this.siteSettings.allow_profile_backgrounds) {
      return htmlSafe("");
    }
    return htmlSafe("background-image: url(" + getURLWithCDN(bgUrl) + ")");
  },

  @discourseComputed()
  path() {
    // no need to observe, requires a hard refresh to update
    return userPath(this.username_lower);
  },

  @discourseComputed()
  userApiKeys() {
    const keys = this.user_api_keys;
    if (keys) {
      return keys.map((raw) => {
        let obj = EmberObject.create(raw);

        obj.revoke = () => {
          this.revokeApiKey(obj);
        };

        obj.undoRevoke = () => {
          this.undoRevokeApiKey(obj);
        };

        return obj;
      });
    }
  },

  revokeApiKey(key) {
    return ajax("/user-api-key/revoke", {
      type: "POST",
      data: { id: key.get("id") },
    }).then(() => {
      key.set("revoked", true);
    });
  },

  undoRevokeApiKey(key) {
    return ajax("/user-api-key/undo-revoke", {
      type: "POST",
      data: { id: key.get("id") },
    }).then(() => {
      key.set("revoked", false);
    });
  },

  pmPath(topic) {
    const userId = this.id;
    const username = this.username_lower;

    const details = topic && topic.get("details");
    const allowedUsers = details && details.get("allowed_users");
    const groups = details && details.get("allowed_groups");

    // directly targeted so go to inbox
    if (!groups || (allowedUsers && allowedUsers.findBy("id", userId))) {
      return userPath(`${username}/messages`);
    } else {
      if (groups && groups[0]) {
        return userPath(`${username}/messages/group/${groups[0].name}`);
      }
    }
  },

  adminPath: url("id", "username_lower", "/admin/users/%@1/%@2"),

  @discourseComputed()
  mutedTopicsPath() {
    return defaultHomepage() === "latest"
      ? getURL("/?state=muted")
      : getURL("/latest?state=muted");
  },

  @discourseComputed()
  watchingTopicsPath() {
    return defaultHomepage() === "latest"
      ? getURL("/?state=watching")
      : getURL("/latest?state=watching");
  },

  @discourseComputed()
  trackingTopicsPath() {
    return defaultHomepage() === "latest"
      ? getURL("/?state=tracking")
      : getURL("/latest?state=tracking");
  },

  @discourseComputed("username")
  username_lower(username) {
    return username.toLowerCase();
  },

  @discourseComputed("trust_level")
  trustLevel(trustLevel) {
    return Site.currentProp("trustLevels").findBy(
      "id",
      parseInt(trustLevel, 10)
    );
  },

  isBasic: equal("trust_level", 0),
  isRegular: equal("trust_level", 3),
  isLeader: equal("trust_level", 4),
  canManageTopic: or("staff", "isLeader"),

  @discourseComputed("previous_visit_at")
  previousVisitAt(previous_visit_at) {
    return new Date(previous_visit_at);
  },

  @discourseComputed("suspended_till")
  suspended(suspendedTill) {
    return suspendedTill && moment(suspendedTill).isAfter();
  },

  @discourseComputed("suspended_till")
  suspendedForever: isForever,

  @discourseComputed("silenced_till")
  silencedForever: isForever,

  @discourseComputed("suspended_till")
  suspendedTillDate: longDate,

  @discourseComputed("silenced_till")
  silencedTillDate: longDate,

  sidebarCategoryIds: alias("sidebar_category_ids"),

  @discourseComputed("sidebar_tags.[]")
  sidebarTags(sidebarTags) {
    if (!sidebarTags || sidebarTags.length === 0) {
      return [];
    }

    return sidebarTags.sort((a, b) => {
      return a.name.localeCompare(b.name);
    });
  },

  sidebarSections: alias("sidebar_sections"),

  sidebarTagNames: mapBy("sidebarTags", "name"),
  sidebarListDestination: readOnly("sidebar_list_destination"),

  changeUsername(new_username) {
    return ajax(userPath(`${this.username_lower}/preferences/username`), {
      type: "PUT",
      data: { new_username },
    });
  },

  addEmail(email) {
    return ajax(userPath(`${this.username_lower}/preferences/email`), {
      type: "POST",
      data: { email },
    });
  },

  changeEmail(email) {
    return ajax(userPath(`${this.username_lower}/preferences/email`), {
      type: "PUT",
      data: { email },
    });
  },

  copy() {
    return User.create(this.getProperties(Object.keys(this)));
  },

  save(fields) {
    const data = this.getProperties(
      userFields.filter((uf) => !fields || fields.includes(uf))
    );

    const filteredUserOptionFields = fields
      ? userOptionFields.filter((uo) => fields.includes(uo))
      : userOptionFields;

    filteredUserOptionFields.forEach((s) => {
      data[s] = this.get(`user_option.${s}`);
    });

    const updatedState = {};

    ["muted", "regular", "watched", "tracked", "watched_first_post"].forEach(
      (categoryNotificationLevel) => {
        if (
          fields === undefined ||
          fields.includes(`${categoryNotificationLevel}_category_ids`)
        ) {
          const categories = this.get(
            `${camelize(categoryNotificationLevel)}Categories`
          );

          if (categories) {
            const ids = categories.map((c) => c.get("id"));
            updatedState[`${categoryNotificationLevel}_category_ids`] = ids;
            // HACK: Empty arrays are not sent in the request, we use [-1],
            // an invalid category ID, that will be ignored by the server.
            data[`${categoryNotificationLevel}_category_ids`] =
              ids.length === 0 ? [-1] : ids;
          }
        }
      }
    );

    [
      "muted_tags",
      "tracked_tags",
      "watched_tags",
      "watching_first_post_tags",
    ].forEach((prop) => {
      if (fields === undefined || fields.includes(prop)) {
        data[prop] = this.get(prop) ? this.get(prop).join(",") : "";
      }
    });

    ["sidebar_category_ids", "sidebar_tag_names"].forEach((prop) => {
      if (data[prop]?.length === 0) {
        data[prop] = null;
      }
    });

    // TODO: We can remove this when migrated fully to rest model.
    this.set("isSaving", true);
    return ajax(userPath(`${this.username_lower}.json`), {
      data,
      type: "PUT",
    })
      .then((result) => {
        this.setProperties(updatedState);
        this.setProperties(getProperties(result.user, "bio_excerpt"));
        return result;
      })
      .finally(() => {
        this.set("isSaving", false);
      });
  },

  setPrimaryEmail(email) {
    return ajax(userPath(`${this.username}/preferences/primary-email.json`), {
      type: "PUT",
      data: { email },
    }).then(() => {
      this.secondary_emails.removeObject(email);
      this.secondary_emails.pushObject(this.email);
      this.set("email", email);
    });
  },

  destroyEmail(email) {
    return ajax(userPath(`${this.username}/preferences/email.json`), {
      type: "DELETE",
      data: { email },
    }).then(() => {
      if (this.unconfirmed_emails.includes(email)) {
        this.unconfirmed_emails.removeObject(email);
      } else {
        this.secondary_emails.removeObject(email);
      }
    });
  },

  changePassword() {
    return ajax("/session/forgot_password", {
      dataType: "json",
      data: { login: this.email || this.username },
      type: "POST",
    });
  },

  loadSecondFactorCodes(password) {
    return ajax("/u/second_factors.json", {
      data: { password },
      type: "POST",
    });
  },

  requestSecurityKeyChallenge() {
    return ajax("/u/create_second_factor_security_key.json", {
      type: "POST",
    });
  },

  registerSecurityKey(credential) {
    return ajax("/u/register_second_factor_security_key.json", {
      data: credential,
      type: "POST",
    });
  },

  createSecondFactorTotp() {
    return ajax("/u/create_second_factor_totp.json", {
      type: "POST",
    });
  },

  enableSecondFactorTotp(authToken, name) {
    return ajax("/u/enable_second_factor_totp.json", {
      data: {
        second_factor_token: authToken,
        name,
      },
      type: "POST",
    });
  },

  disableAllSecondFactors() {
    return ajax("/u/disable_second_factor.json", {
      type: "PUT",
    });
  },

  updateSecondFactor(id, name, disable, targetMethod) {
    return ajax("/u/second_factor.json", {
      data: {
        second_factor_target: targetMethod,
        name,
        disable,
        id,
      },
      type: "PUT",
    });
  },

  updateSecurityKey(id, name, disable) {
    return ajax("/u/security_key.json", {
      data: {
        name,
        disable,
        id,
      },
      type: "PUT",
    });
  },

  toggleSecondFactor(authToken, authMethod, targetMethod, enable) {
    return ajax("/u/second_factor.json", {
      data: {
        second_factor_token: authToken,
        second_factor_method: authMethod,
        second_factor_target: targetMethod,
        enable,
      },
      type: "PUT",
    });
  },

  generateSecondFactorCodes() {
    return ajax("/u/second_factors_backup.json", {
      type: "PUT",
    });
  },

  revokeAssociatedAccount(providerName) {
    return ajax(userPath(`${this.username}/preferences/revoke-account`), {
      data: { provider_name: providerName },
      type: "POST",
    });
  },

  async loadUserAction(id) {
    const result = await ajax(`/user_actions/${id}.json`);

    if (!result?.user_action) {
      return;
    }

    const ua = result.user_action;

    if ((this.get("stream.filter") || ua.action_type) !== ua.action_type) {
      return;
    }

    if (!this.get("stream.filter") && !this.inAllStream(ua)) {
      return;
    }

    ua.title = emojiUnescape(escapeExpression(ua.title));
    const action = UserAction.collapseStream([UserAction.create(ua)]);
    this.stream.set("itemsLoaded", this.stream.get("itemsLoaded") + 1);
    this.stream.get("content").insertAt(0, action[0]);
  },

  inAllStream(ua) {
    return (
      ua.action_type === UserAction.TYPES.posts ||
      ua.action_type === UserAction.TYPES.topics
    );
  },

  numGroupsToDisplay: 2,

  @discourseComputed("groups.[]")
  filteredGroups() {
    const groups = this.groups || [];

    return groups.filter((group) => {
      return !group.automatic || group.name === "moderators";
    });
  },

  groupsWithMessages: filterBy("groups", "has_messages", true),

  @discourseComputed("filteredGroups", "numGroupsToDisplay")
  displayGroups(filteredGroups, numGroupsToDisplay) {
    const groups = filteredGroups.slice(0, numGroupsToDisplay);
    return groups.length === 0 ? null : groups;
  },

  @discourseComputed("filteredGroups", "numGroupsToDisplay")
  showMoreGroupsLink(filteredGroups, numGroupsToDisplay) {
    return filteredGroups.length > numGroupsToDisplay;
  },

  // NOTE: This only includes groups *visible* to the user via the serializer,
  // so be wary when using this.
  isInAnyGroups(groupIds) {
    if (!this.groups) {
      return;
    }

    // auto group ID 0 is "everyone"
    return (
      groupIds.includes(0) ||
      this.groups.mapBy("id").some((groupId) => groupIds.includes(groupId))
    );
  },

  // The user's stat count, excluding PMs.
  @discourseComputed("statsExcludingPms.@each.count")
  statsCountNonPM() {
    if (isEmpty(this.statsExcludingPms)) {
      return 0;
    }
    let count = 0;
    this.statsExcludingPms.forEach((val) => {
      if (this.inAllStream(val)) {
        count += val.count;
      }
    });
    return count;
  },

  // The user's stats, excluding PMs.
  @discourseComputed("stats.@each.isPM")
  statsExcludingPms() {
    if (isEmpty(this.stats)) {
      return [];
    }
    return this.stats.rejectBy("isPM");
  },

  findDetails(options) {
    const user = this;

    return PreloadStore.getAndRemove(`user_${user.get("username")}`, () => {
      if (options && options.existingRequest) {
        // Existing ajax request has been passed, use it
        return options.existingRequest;
      }

      const useCardRoute = options && options.forCard;
      if (options) {
        delete options.forCard;
      }

      const path = useCardRoute
        ? `${user.get("username")}/card.json`
        : `${user.get("username")}.json`;

      return ajax(userPath(path), { data: options });
    }).then((json) => {
      if (!isEmpty(json.user.stats)) {
        json.user.stats = User.groupStats(
          json.user.stats.map((s) => {
            if (s.count) {
              s.count = parseInt(s.count, 10);
            }
            return UserActionStat.create(s);
          })
        );
      }

      if (!isEmpty(json.user.groups) && !isEmpty(json.user.group_users)) {
        const groups = [];

        for (let i = 0; i < json.user.groups.length; i++) {
          const group = Group.create(json.user.groups[i]);
          group.group_user = json.user.group_users[i];
          groups.push(group);
        }

        json.user.groups = groups;
      }

      if (json.user.invited_by) {
        json.user.invited_by = User.create(json.user.invited_by);
      }

      if (!isEmpty(json.user.featured_user_badge_ids)) {
        const userBadgesMap = {};
        UserBadge.createFromJson(json).forEach((userBadge) => {
          userBadgesMap[userBadge.get("id")] = userBadge;
        });
        json.user.featured_user_badges = json.user.featured_user_badge_ids.map(
          (id) => userBadgesMap[id]
        );
      }

      if (json.user.card_badge) {
        json.user.card_badge = Badge.create(json.user.card_badge);
      }

      user.setProperties(json.user);
      return user;
    });
  },

  findStaffInfo() {
    if (!User.currentProp("staff")) {
      return Promise.resolve(null);
    }
    return ajax(userPath(`${this.username_lower}/staff-info.json`)).then(
      (info) => {
        this.setProperties(info);
      }
    );
  },

  pickAvatar(upload_id, type) {
    return ajax(userPath(`${this.username_lower}/preferences/avatar/pick`), {
      type: "PUT",
      data: { upload_id, type },
    });
  },

  selectAvatar(avatarUrl) {
    return ajax(userPath(`${this.username_lower}/preferences/avatar/select`), {
      type: "PUT",
      data: { url: avatarUrl },
    });
  },

  isAllowedToUploadAFile(type) {
    const settingName = type === "image" ? "embedded_media" : "attachments";

    return (
      this.staff ||
      this.trust_level > 0 ||
      this.siteSettings[`newuser_max_${settingName}`] > 0
    );
  },

  createInvite(email, group_ids, custom_message) {
    return ajax("/invites", {
      type: "POST",
      data: { email, group_ids, custom_message },
    });
  },

  generateInviteLink(email, group_ids, topic_id) {
    return ajax("/invites", {
      type: "POST",
      data: { email, skip_email: true, group_ids, topic_id },
    });
  },

  generateMultipleUseInviteLink(
    group_ids,
    max_redemptions_allowed,
    expires_at
  ) {
    return ajax("/invites", {
      type: "POST",
      data: { group_ids, max_redemptions_allowed, expires_at },
    });
  },

  @dependentKeyCompat
  get mutedCategories() {
    return Category.findByIds(this.get("muted_category_ids"));
  },
  set mutedCategories(categories) {
    this.set(
      "muted_category_ids",
      categories.map((c) => c.id)
    );
  },

  @dependentKeyCompat
  get regularCategories() {
    return Category.findByIds(this.get("regular_category_ids"));
  },
  set regularCategories(categories) {
    this.set(
      "regular_category_ids",
      categories.map((c) => c.id)
    );
  },

  @dependentKeyCompat
  get trackedCategories() {
    return Category.findByIds(this.get("tracked_category_ids"));
  },
  set trackedCategories(categories) {
    this.set(
      "tracked_category_ids",
      categories.map((c) => c.id)
    );
  },

  @dependentKeyCompat
  get watchedCategories() {
    return Category.findByIds(this.get("watched_category_ids"));
  },
  set watchedCategories(categories) {
    this.set(
      "watched_category_ids",
      categories.map((c) => c.id)
    );
  },

  @dependentKeyCompat
  get watchedFirstPostCategories() {
    return Category.findByIds(this.get("watched_first_post_category_ids"));
  },
  set watchedFirstPostCategories(categories) {
    this.set(
      "watched_first_post_category_ids",
      categories.map((c) => c.id)
    );
  },

  @discourseComputed("can_delete_account")
  canDeleteAccount(canDeleteAccount) {
    return !this.siteSettings.enable_discourse_connect && canDeleteAccount;
  },

  delete() {
    if (this.can_delete_account) {
      return ajax(userPath(this.username + ".json"), {
        type: "DELETE",
        data: { context: window.location.pathname },
      });
    } else {
      return Promise.reject(I18n.t("user.delete_yourself_not_allowed"));
    }
  },

  updateNotificationLevel({ level, expiringAt = null, actingUser = null }) {
    if (!actingUser) {
      actingUser = User.current();
    }
    return ajax(`${userPath(this.username)}/notification_level.json`, {
      type: "PUT",
      data: {
        notification_level: level,
        expiring_at: expiringAt,
        acting_user_id: actingUser.id,
      },
    }).then(() => {
      if (!actingUser.ignored_users) {
        actingUser.ignored_users = [];
      }
      if (level === "normal" || level === "mute") {
        actingUser.ignored_users.removeObject(this.username);
      } else if (level === "ignore") {
        actingUser.ignored_users.addObject(this.username);
      }
    });
  },

  dismissBanner(bannerKey) {
    this.set("dismissed_banner_key", bannerKey);
    ajax(userPath(this.username + ".json"), {
      type: "PUT",
      data: { dismissed_banner_key: bannerKey },
    });
  },

  checkEmail() {
    return ajax(userPath(`${this.username_lower}/emails.json`), {
      data: { context: window.location.pathname },
    }).then((result) => {
      if (result) {
        this.setProperties({
          email: result.email,
          secondary_emails: result.secondary_emails,
          unconfirmed_emails: result.unconfirmed_emails,
          associated_accounts: result.associated_accounts,
        });
      }
    });
  },

  summary() {
    const store = getOwner(this).lookup("service:store");

    return ajax(userPath(`${this.username_lower}/summary.json`)).then(
      (json) => {
        const summary = json.user_summary;
        const topicMap = {};
        const badgeMap = {};

        json.topics.forEach(
          (t) => (topicMap[t.id] = store.createRecord("topic", t))
        );
        Badge.createFromJson(json).forEach((b) => (badgeMap[b.id] = b));

        summary.topics = summary.topic_ids.map((id) => topicMap[id]);

        summary.replies.forEach((r) => {
          r.topic = topicMap[r.topic_id];
          r.url = r.topic.urlForPostNumber(r.post_number);
          r.createdAt = new Date(r.created_at);
        });

        summary.links.forEach((l) => {
          l.topic = topicMap[l.topic_id];
          l.post_url = l.topic.urlForPostNumber(l.post_number);
        });

        if (summary.badges) {
          summary.badges = summary.badges.map((ub) => {
            const badge = badgeMap[ub.badge_id];
            badge.count = ub.count;
            return badge;
          });
        }

        if (summary.top_categories) {
          summary.top_categories.forEach((c) => {
            if (c.parent_category_id) {
              c.parentCategory = Category.findById(c.parent_category_id);
            }
          });
        }

        return summary;
      }
    );
  },

  canManageGroup(group) {
    return group.get("automatic")
      ? false
      : group.get("can_admin_group") || group.get("is_group_owner");
  },

  @discourseComputed("groups.@each.title", "badges.[]")
  availableTitles() {
    const titles = [];

    (this.groups || []).forEach((group) => {
      if (get(group, "title")) {
        titles.push(get(group, "title"));
      }
    });

    (this.badges || []).forEach((badge) => {
      if (get(badge, "allow_title")) {
        titles.push(get(badge, "name"));
      }
    });

    return titles
      .uniq()
      .sort()
      .map((title) => {
        return {
          name: escapeExpression(title),
          id: title,
        };
      });
  },

  @discourseComputed("groups.[]")
  availableFlairs() {
    const flairs = [];

    if (this.groups) {
      this.groups.forEach((group) => {
        if (group.flair_url) {
          flairs.push({
            id: group.id,
            name: group.name,
            url: group.flair_url,
            bgColor: group.flair_bg_color,
            color: group.flair_color,
          });
        }
      });
    }

    return flairs;
  },

  @discourseComputed("user_option.text_size_seq", "user_option.text_size")
  currentTextSize(serverSeq, serverSize) {
    if (cookie(TEXT_SIZE_COOKIE_NAME)) {
      const [cookieSize, cookieSeq] = cookie(TEXT_SIZE_COOKIE_NAME).split("|");
      if (cookieSeq >= serverSeq) {
        return cookieSize;
      }
    }
    return serverSize;
  },

  updateTextSizeCookie(newSize) {
    if (newSize) {
      const seq = this.get("user_option.text_size_seq");
      cookie(TEXT_SIZE_COOKIE_NAME, `${newSize}|${seq}`, {
        path: "/",
        expires: COOKIE_EXPIRY_DAYS,
      });
    } else {
      removeCookie(TEXT_SIZE_COOKIE_NAME, { path: "/" });
    }
  },

  @discourseComputed("second_factor_enabled", "staff")
  enforcedSecondFactor(secondFactorEnabled, staff) {
    const enforce = this.siteSettings.enforce_second_factor;
    return (
      !secondFactorEnabled &&
      (enforce === "all" || (enforce === "staff" && staff))
    );
  },

  resolvedTimezone() {
    deprecated(
      "user.resolvedTimezone() has been deprecated. Use user.user_option.timezone instead",
      {
        id: "discourse.user.resolved-timezone",
        since: "2.9.0.beta12",
        dropFrom: "3.0.0.beta1",
      }
    );

    return this.user_option.timezone;
  },

  calculateMutedIds(notificationLevel, id, type) {
    const muted_ids = this.get(type);
    if (notificationLevel === NotificationLevels.MUTED) {
      return muted_ids.concat(id).uniq();
    } else {
      return muted_ids.filter((existing_id) => existing_id !== id);
    }
  },

  setPrimaryGroup(primaryGroupId) {
    return ajax(`/admin/users/${this.id}/primary_group`, {
      type: "PUT",
      data: { primary_group_id: primaryGroupId },
    });
  },

  enterDoNotDisturbFor(duration) {
    return ajax({
      url: "/do-not-disturb.json",
      type: "POST",
      data: { duration },
    }).then((response) => {
      return this.updateDoNotDisturbStatus(response.ends_at);
    });
  },

  leaveDoNotDisturb() {
    return ajax({
      url: "/do-not-disturb.json",
      type: "DELETE",
    }).then(() => {
      this.updateDoNotDisturbStatus(null);
    });
  },

  updateDoNotDisturbStatus(ends_at) {
    this.set("do_not_disturb_until", ends_at);
    this.appEvents.trigger("do-not-disturb:changed", this.do_not_disturb_until);
  },

  updateDraftProperties(properties) {
    this.setProperties(properties);
    this.appEvents.trigger("user-drafts:changed");
  },

  updateReviewableCount(count) {
    this.set("reviewable_count", count);
    this.appEvents.trigger("user-reviewable-count:changed", count);
  },

  isInDoNotDisturb() {
    return (
      this.do_not_disturb_until &&
      new Date(this.do_not_disturb_until) >= new Date()
    );
  },

  @discourseComputed(
    "tracked_tags.[]",
    "watched_tags.[]",
    "watching_first_post_tags.[]"
  )
  trackedTags(trackedTags, watchedTags, watchingFirstPostTags) {
    return [...trackedTags, ...watchedTags, ...watchingFirstPostTags];
  },

  showUserTip(options) {
    const userTips = Site.currentProp("user_tips");
    if (!userTips || this.skip_new_user_tips) {
      return;
    }

    if (!userTips[options.id]) {
      if (!isTesting()) {
        // eslint-disable-next-line no-console
        console.warn("Cannot show user tip with type =", options.id);
      }
      return;
    }

    const seenUserTips = this.seen_popups || [];
    if (
      seenUserTips.includes(-1) ||
      seenUserTips.includes(userTips[options.id])
    ) {
      return;
    }

    showUserTip({
      ...options,
      onDismiss: () => this.hideUserTipForever(options.id),
      onDismissAll: () => this.hideUserTipForever(),
    });
  },

  hideUserTipForever(userTipId) {
    const userTips = Site.currentProp("user_tips");
    if (!userTips || this.skip_new_user_tips) {
      return;
    }

    // Empty userTipId means all user tips.
    if (userTipId && !userTips[userTipId]) {
      // eslint-disable-next-line no-console
      console.warn("Cannot hide user tip with type =", userTipId);
      return;
    }

    // Hide user tips and maybe show the next one.
    if (userTipId) {
      hideUserTip(userTipId);
      showNextUserTip();
    } else {
      hideAllUserTips();
    }

    // Update list of seen user tips.
    let seenUserTips = this.seen_popups || [];
    if (userTipId) {
      if (seenUserTips.includes(userTips[userTipId])) {
        return;
      }
      seenUserTips.push(userTips[userTipId]);
    } else {
      if (seenUserTips.includes(-1)) {
        return;
      }
      seenUserTips = [-1];
    }

    // Save seen user tips on the server.
    if (!this.user_option) {
      this.set("user_option", {});
    }
    this.set("user_option.seen_popups", seenUserTips);
    if (userTipId) {
      return this.save(["seen_popups"]);
    } else {
      this.set("user_option.skip_new_user_tips", true);
      return this.save(["seen_popups", "skip_new_user_tips"]);
    }
  },
});

User.reopenClass(Singleton, {
  // Find a `User` for a given username.
  findByUsername(username, options) {
    const user = User.create({ username });
    return user.findDetails(options);
  },

  // TODO: Use app.register and junk Singleton
  createCurrent() {
    const userJson = PreloadStore.get("currentUser");
    if (userJson) {
      userJson.isCurrent = true;

      if (userJson.primary_group_id) {
        const primaryGroup = userJson.groups.find(
          (group) => group.id === userJson.primary_group_id
        );
        if (primaryGroup) {
          userJson.primary_group_name = primaryGroup.name;
        }
      }

      if (!userJson.user_option.timezone) {
        userJson.user_option.timezone = moment.tz.guess();
        this._saveTimezone(userJson);
      }

      const store = getOwner(this).lookup("service:store");
      const currentUser = store.createRecord("user", userJson);
      currentUser.trackStatus();
      return currentUser;
    }

    return null;
  },

  checkUsername(username, email, for_user_id) {
    return ajax(userPath("check_username"), {
      data: { username, email, for_user_id },
    });
  },

  checkEmail(email) {
    return ajax(userPath("check_email"), { data: { email } });
  },

  loadRecentSearches() {
    return ajax(`/u/recent-searches`);
  },

  resetRecentSearches() {
    return ajax(`/u/recent-searches`, { type: "DELETE" });
  },

  groupStats(stats) {
    const responses = UserActionStat.create({
      count: 0,
      action_type: UserAction.TYPES.replies,
    });

    stats.filterBy("isResponse").forEach((stat) => {
      responses.set("count", responses.get("count") + stat.get("count"));
    });

    const result = A();
    result.pushObjects(stats.rejectBy("isResponse"));

    let insertAt = 0;
    result.forEach((item, index) => {
      if (
        item.action_type === UserAction.TYPES.topics ||
        item.action_type === UserAction.TYPES.posts
      ) {
        insertAt = index + 1;
      }
    });
    if (responses.count > 0) {
      result.insertAt(insertAt, responses);
    }
    return result;
  },

  createAccount(attrs) {
    let data = {
      name: attrs.accountName,
      email: attrs.accountEmail,
      password: attrs.accountPassword,
      username: attrs.accountUsername,
      password_confirmation: attrs.accountPasswordConfirm,
      challenge: attrs.accountChallenge,
      user_fields: attrs.userFields,
      timezone: moment.tz.guess(),
    };

    if (attrs.inviteCode) {
      data.invite_code = attrs.inviteCode;
    }

    return ajax(userPath(), {
      data,
      type: "POST",
    });
  },

  _saveTimezone(user) {
    ajax(userPath(user.username + ".json"), {
      type: "PUT",
      dataType: "json",
      data: { timezone: user.user_option.timezone },
    });
  },
});

User.reopenClass({
  create(args) {
    args = args || {};
    this.deleteStatusTrackingFields(args);
    return this._super(args);
  },

  deleteStatusTrackingFields(args) {
    // every user instance has to have it's own tracking fields
    // when creating a new user model
    // its _subscribersCount and _clearStatusTimerId fields
    // should be equal to 0 and null
    // here we makes sure that even if these fields
    // will be passed in args they won't be set anyway
    //
    // this is something that could be implemented by making these fields private,
    // but EmberObject doesn't support private fields
    if (args.hasOwnProperty("_subscribersCount")) {
      delete args._subscribersCount;
    }
    if (args.hasOwnProperty("_clearStatusTimerId")) {
      delete args._clearStatusTimerId;
    }
  },
});

// user status tracking
User.reopen(Evented, {
  _subscribersCount: 0,
  _clearStatusTimerId: null,

  // always call stopTrackingStatus() when done with a user
  trackStatus() {
    if (this._subscribersCount === 0) {
      this.addObserver("status", this, "_statusChanged");

      this.appEvents.on("user-status:changed", this, this._updateStatus);

      if (this.status && this.status.ends_at) {
        this._scheduleStatusClearing(this.status.ends_at);
      }
    }

    this._subscribersCount++;
  },

  stopTrackingStatus() {
    if (this._subscribersCount === 0) {
      return;
    }

    if (this._subscribersCount === 1) {
      // the last subscriber is unsubscribing
      this.removeObserver("status", this, "_statusChanged");
      this.appEvents.off("user-status:changed", this, this._updateStatus);
      this._unscheduleStatusClearing();
    }

    this._subscribersCount--;
  },

  _statusChanged(sender, key) {
    this.trigger("status-changed");

    const status = this.get(key);
    if (status && status.ends_at) {
      this._scheduleStatusClearing(status.ends_at);
    } else {
      this._unscheduleStatusClearing();
    }
  },

  _scheduleStatusClearing(endsAt) {
    if (isTesting()) {
      return;
    }

    if (this._clearStatusTimerId) {
      this._unscheduleStatusClearing();
    }

    const utcNow = moment.utc();
    const remaining = moment.utc(endsAt).diff(utcNow, "milliseconds");
    this._clearStatusTimerId = discourseLater(
      this,
      "_autoClearStatus",
      remaining
    );
  },

  _unscheduleStatusClearing() {
    cancel(this._clearStatusTimerId);
    this._clearStatusTimerId = null;
  },

  _autoClearStatus() {
    this.set("status", null);
  },

  _updateStatus(statuses) {
    if (statuses.hasOwnProperty(this.id)) {
      this.set("status", statuses[this.id]);
    }
  },
});

if (typeof Discourse !== "undefined") {
  let warned = false;
  // eslint-disable-next-line no-undef
  Object.defineProperty(Discourse, "User", {
    get() {
      if (!warned) {
        deprecated("Import the User class instead of using Discourse.User", {
          since: "2.4.0",
          id: "discourse.globals.user",
        });
        warned = true;
      }
      return User;
    },
  });
}

export default User;
