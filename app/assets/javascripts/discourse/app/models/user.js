import EmberObject, { computed, get, getProperties } from "@ember/object";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { defaultHomepage, escapeExpression } from "discourse/lib/utilities";
import { equal, filterBy, gt, or } from "@ember/object/computed";
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

export const SECOND_FACTOR_METHODS = {
  TOTP: 1,
  BACKUP_CODE: 2,
  SECURITY_KEY: 3,
};

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
  "default_calendar",
];

export function addSaveableUserOptionField(fieldName) {
  userOptionFields.push(fieldName);
}

const User = RestModel.extend({
  hasPMs: gt("private_messages_stats.all", 0),
  hasStartedPMs: gt("private_messages_stats.mine", 0),
  hasUnreadPMs: gt("private_messages_stats.unread", 0),

  redirected_to_top: {
    reason: null,
  },

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
      return "".htmlSafe();
    }
    return ("background-image: url(" + getURLWithCDN(bgUrl) + ")").htmlSafe();
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
  isLeader: equal("trust_level", 3),
  isElder: equal("trust_level", 4),
  canManageTopic: or("staff", "isElder"),

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
      userFields.filter((uf) => !fields || fields.indexOf(uf) !== -1)
    );

    let filteredUserOptionFields = [];
    if (fields) {
      filteredUserOptionFields = userOptionFields.filter(
        (uo) => fields.indexOf(uo) !== -1
      );
    } else {
      filteredUserOptionFields = userOptionFields;
    }

    filteredUserOptionFields.forEach((s) => {
      data[s] = this.get(`user_option.${s}`);
    });

    let updatedState = {};

    ["muted", "regular", "watched", "tracked", "watched_first_post"].forEach(
      (s) => {
        if (fields === undefined || fields.includes(s + "_category_ids")) {
          let prop =
            s === "watched_first_post"
              ? "watchedFirstPostCategories"
              : s + "Categories";
          let cats = this.get(prop);
          if (cats) {
            let cat_ids = cats.map((c) => c.get("id"));
            updatedState[s + "_category_ids"] = cat_ids;

            // HACK: denote lack of categories
            if (cats.length === 0) {
              cat_ids = [-1];
            }
            data[s + "_category_ids"] = cat_ids;
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

    return this._saveUserData(data, updatedState);
  },

  _saveUserData(data, updatedState) {
    // TODO: We can remove this when migrated fully to rest model.
    this.set("isSaving", true);
    return ajax(userPath(`${this.username_lower}.json`), {
      data,
      type: "PUT",
    })
      .then((result) => {
        this.set("bio_excerpt", result.user.bio_excerpt);
        const userProps = getProperties(
          this.user_option,
          "enable_quoting",
          "enable_defer",
          "external_links_in_new_tab",
          "dynamic_favicon"
        );
        User.current().setProperties(userProps);
        this.setProperties(updatedState);
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

  loadUserAction(id) {
    const stream = this.stream;
    return ajax(`/user_actions/${id}.json`).then((result) => {
      if (result && result.user_action) {
        const ua = result.user_action;

        if ((this.get("stream.filter") || ua.action_type) !== ua.action_type) {
          return;
        }
        if (!this.get("stream.filter") && !this.inAllStream(ua)) {
          return;
        }

        ua.title = emojiUnescape(escapeExpression(ua.title));
        const action = UserAction.collapseStream([UserAction.create(ua)]);
        stream.set("itemsLoaded", stream.get("itemsLoaded") + 1);
        stream.get("content").insertAt(0, action[0]);
      }
    });
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

      if (!json.user._timezone) {
        json.user._timezone = json.user.timezone;
        delete json.user.timezone;
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

  @discourseComputed("muted_category_ids")
  mutedCategories(mutedCategoryIds) {
    return Category.findByIds(mutedCategoryIds);
  },

  @discourseComputed("regular_category_ids")
  regularCategories(regularCategoryIds) {
    return Category.findByIds(regularCategoryIds);
  },

  @discourseComputed("tracked_category_ids")
  trackedCategories(trackedCategoryIds) {
    return Category.findByIds(trackedCategoryIds);
  },

  @discourseComputed("watched_category_ids")
  watchedCategories(watchedCategoryIds) {
    return Category.findByIds(watchedCategoryIds);
  },

  @discourseComputed("watched_first_post_category_ids")
  watchedFirstPostCategories(wachedFirstPostCategoryIds) {
    return Category.findByIds(wachedFirstPostCategoryIds);
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

  updateNotificationLevel(level, expiringAt) {
    return ajax(`${userPath(this.username)}/notification_level.json`, {
      type: "PUT",
      data: { notification_level: level, expiring_at: expiringAt },
    }).then(() => {
      const currentUser = User.current();
      if (currentUser) {
        if (level === "normal" || level === "mute") {
          currentUser.ignored_users.removeObject(this.username);
        } else if (level === "ignore") {
          currentUser.ignored_users.addObject(this.username);
        }
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
    if (cookie("text_size")) {
      const [cookieSize, cookieSeq] = cookie("text_size").split("|");
      if (cookieSeq >= serverSeq) {
        return cookieSize;
      }
    }
    return serverSize;
  },

  updateTextSizeCookie(newSize) {
    if (newSize) {
      const seq = this.get("user_option.text_size_seq");
      cookie("text_size", `${newSize}|${seq}`, {
        path: "/",
        expires: 9999,
      });
    } else {
      removeCookie("text_size", { path: "/", expires: 1 });
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

  resolvedTimezone(currentUser) {
    if (this.hasSavedTimezone()) {
      return this._timezone;
    }

    // only change the timezone and save it if we are
    // looking at our own user
    if (currentUser.id === this.id) {
      this.changeTimezone(moment.tz.guess());
      ajax(userPath(this.username + ".json"), {
        type: "PUT",
        dataType: "json",
        data: { timezone: this._timezone },
      });
    }

    return this._timezone;
  },

  changeTimezone(tz) {
    this._timezone = tz;
  },

  hasSavedTimezone() {
    if (this._timezone) {
      return true;
    }
    return false;
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

  isInDoNotDisturb() {
    return (
      this.do_not_disturb_until &&
      new Date(this.do_not_disturb_until) >= new Date()
    );
  },
});

User.reopenClass(Singleton, {
  munge(json) {
    // timezone should not be directly accessed, use
    // resolvedTimezone() and changeTimezone(tz)
    if (!json._timezone) {
      json._timezone = json.timezone;
      delete json.timezone;
    }

    return json;
  },

  // Find a `User` for a given username.
  findByUsername(username, options) {
    const user = User.create({ username });
    return user.findDetails(options);
  },

  // TODO: Use app.register and junk Singleton
  createCurrent() {
    let userJson = PreloadStore.get("currentUser");

    if (userJson && userJson.primary_group_id) {
      const primaryGroup = userJson.groups.find(
        (group) => group.id === userJson.primary_group_id
      );
      if (primaryGroup) {
        userJson.primary_group_name = primaryGroup.name;
      }
    }

    if (userJson) {
      userJson = User.munge(userJson);
      const store = getOwner(this).lookup("service:store");
      return store.createRecord("user", userJson);
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
});

if (typeof Discourse !== "undefined") {
  let warned = false;
  // eslint-disable-next-line no-undef
  Object.defineProperty(Discourse, "User", {
    get() {
      if (!warned) {
        deprecated("Import the User class instead of using User", {
          since: "2.4.0",
          dropFrom: "2.6.0",
        });
        warned = true;
      }
      return User;
    },
  });
}

export default User;
