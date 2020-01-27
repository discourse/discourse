import { isEmpty } from "@ember/utils";
import { gt, equal, or } from "@ember/object/computed";
import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import RestModel from "discourse/models/rest";
import UserStream from "discourse/models/user-stream";
import UserPostsStream from "discourse/models/user-posts-stream";
import Singleton from "discourse/mixins/singleton";
import { longDate } from "discourse/lib/formatter";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import UserActionStat from "discourse/models/user-action-stat";
import UserAction from "discourse/models/user-action";
import UserDraftsStream from "discourse/models/user-drafts-stream";
import Group from "discourse/models/group";
import { emojiUnescape } from "discourse/lib/text";
import PreloadStore from "preload-store";
import { defaultHomepage } from "discourse/lib/utilities";
import { userPath } from "discourse/lib/url";
import Category from "discourse/models/category";
import { Promise } from "rsvp";
import { getProperties } from "@ember/object";
import deprecated from "discourse-common/lib/deprecated";
import Site from "discourse/models/site";

export const SECOND_FACTOR_METHODS = {
  TOTP: 1,
  BACKUP_CODE: 2,
  SECURITY_KEY: 3
};

const isForever = dt => moment().diff(dt, "years") < -500;

const User = RestModel.extend({
  hasPMs: gt("private_messages_stats.all", 0),
  hasStartedPMs: gt("private_messages_stats.mine", 0),
  hasUnreadPMs: gt("private_messages_stats.unread", 0),

  redirected_to_top: {
    reason: null
  },

  @discourseComputed("can_be_deleted", "post_count")
  canBeDeleted(canBeDeleted, postCount) {
    return canBeDeleted && postCount <= 5;
  },

  @discourseComputed()
  stream() {
    return UserStream.create({ user: this });
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
    }
  }),

  destroySession() {
    return ajax(`/session/${this.username}`, { type: "DELETE" });
  },

  @discourseComputed("username_lower")
  searchContext(username) {
    return {
      type: "user",
      id: username,
      user: this
    };
  },

  @discourseComputed("username", "name")
  displayName(username, name) {
    if (Discourse.SiteSettings.enable_names && !isEmpty(name)) {
      return name;
    }
    return username;
  },

  @discourseComputed("profile_background_upload_url")
  profileBackgroundUrl(bgUrl) {
    if (isEmpty(bgUrl) || !Discourse.SiteSettings.allow_profile_backgrounds) {
      return "".htmlSafe();
    }
    return (
      "background-image: url(" +
      Discourse.getURLWithCDN(bgUrl) +
      ")"
    ).htmlSafe();
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
      return keys.map(raw => {
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
      data: { id: key.get("id") }
    }).then(() => {
      key.set("revoked", true);
    });
  },

  undoRevokeApiKey(key) {
    return ajax("/user-api-key/undo-revoke", {
      type: "POST",
      data: { id: key.get("id") }
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

    // directly targetted so go to inbox
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
      ? Discourse.getURL("/?state=muted")
      : Discourse.getURL("/latest?state=muted");
  },

  @discourseComputed()
  watchingTopicsPath() {
    return defaultHomepage() === "latest"
      ? Discourse.getURL("/?state=watching")
      : Discourse.getURL("/latest?state=watching");
  },

  @discourseComputed()
  trackingTopicsPath() {
    return defaultHomepage() === "latest"
      ? Discourse.getURL("/?state=tracking")
      : Discourse.getURL("/latest?state=tracking");
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
      data: { new_username }
    });
  },

  changeEmail(email) {
    return ajax(userPath(`${this.username_lower}/preferences/email`), {
      type: "PUT",
      data: { email }
    });
  },

  copy() {
    return User.create(this.getProperties(Object.keys(this)));
  },

  save(fields) {
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
      "profile_background_upload_url",
      "card_background_upload_url",
      "muted_tags",
      "tracked_tags",
      "watched_tags",
      "watching_first_post_tags",
      "date_of_birth",
      "primary_group_id"
    ];

    const data = this.getProperties(
      fields ? _.intersection(userFields, fields) : userFields
    );

    let userOptionFields = [
      "mailing_list_mode",
      "mailing_list_mode_frequency",
      "external_links_in_new_tab",
      "email_digests",
      "email_in_reply_to",
      "email_messages_level",
      "email_level",
      "email_previous_replies",
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
      "homepage_id",
      "hide_profile_and_presence",
      "text_size",
      "title_count_mode",
      "timezone"
    ];

    if (fields) {
      userOptionFields = _.intersection(userOptionFields, fields);
    }

    userOptionFields.forEach(s => {
      data[s] = this.get(`user_option.${s}`);
    });

    var updatedState = {};

    ["muted", "watched", "tracked", "watched_first_post"].forEach(s => {
      if (fields === undefined || fields.includes(s + "_category_ids")) {
        let prop =
          s === "watched_first_post"
            ? "watchedFirstPostCategories"
            : s + "Categories";
        let cats = this.get(prop);
        if (cats) {
          let cat_ids = cats.map(c => c.get("id"));
          updatedState[s + "_category_ids"] = cat_ids;

          // HACK: denote lack of categories
          if (cats.length === 0) {
            cat_ids = [-1];
          }
          data[s + "_category_ids"] = cat_ids;
        }
      }
    });

    [
      "muted_tags",
      "tracked_tags",
      "watched_tags",
      "watching_first_post_tags"
    ].forEach(prop => {
      if (fields === undefined || fields.includes(prop)) {
        data[prop] = this.get(prop) ? this.get(prop).join(",") : "";
      }
    });

    // TODO: We can remove this when migrated fully to rest model.
    this.set("isSaving", true);
    return ajax(userPath(`${this.username_lower}.json`), {
      data: data,
      type: "PUT"
    })
      .then(result => {
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

  changePassword() {
    return ajax("/session/forgot_password", {
      dataType: "json",
      data: { login: this.username },
      type: "POST"
    });
  },

  loadSecondFactorCodes(password) {
    return ajax("/u/second_factors.json", {
      data: { password },
      type: "POST"
    });
  },

  requestSecurityKeyChallenge() {
    return ajax("/u/create_second_factor_security_key.json", {
      type: "POST"
    });
  },

  registerSecurityKey(credential) {
    return ajax("/u/register_second_factor_security_key.json", {
      data: credential,
      type: "POST"
    });
  },

  createSecondFactorTotp() {
    return ajax("/u/create_second_factor_totp.json", {
      type: "POST"
    });
  },

  enableSecondFactorTotp(authToken, name) {
    return ajax("/u/enable_second_factor_totp.json", {
      data: {
        second_factor_token: authToken,
        name
      },
      type: "POST"
    });
  },

  disableAllSecondFactors() {
    return ajax("/u/disable_second_factor.json", {
      type: "PUT"
    });
  },

  updateSecondFactor(id, name, disable, targetMethod) {
    return ajax("/u/second_factor.json", {
      data: {
        second_factor_target: targetMethod,
        name,
        disable,
        id
      },
      type: "PUT"
    });
  },

  updateSecurityKey(id, name, disable) {
    return ajax("/u/security_key.json", {
      data: {
        name,
        disable,
        id
      },
      type: "PUT"
    });
  },

  toggleSecondFactor(authToken, authMethod, targetMethod, enable) {
    return ajax("/u/second_factor.json", {
      data: {
        second_factor_token: authToken,
        second_factor_method: authMethod,
        second_factor_target: targetMethod,
        enable
      },
      type: "PUT"
    });
  },

  generateSecondFactorCodes() {
    return ajax("/u/second_factors_backup.json", {
      type: "PUT"
    });
  },

  revokeAssociatedAccount(providerName) {
    return ajax(userPath(`${this.username}/preferences/revoke-account`), {
      data: { provider_name: providerName },
      type: "POST"
    });
  },

  loadUserAction(id) {
    const stream = this.stream;
    return ajax(`/user_actions/${id}.json`, { cache: "false" }).then(result => {
      if (result && result.user_action) {
        const ua = result.user_action;

        if ((this.get("stream.filter") || ua.action_type) !== ua.action_type)
          return;
        if (!this.get("stream.filter") && !this.inAllStream(ua)) return;

        ua.title = emojiUnescape(Handlebars.Utils.escapeExpression(ua.title));
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

    return groups.filter(group => {
      return !group.automatic || group.name === "moderators";
    });
  },

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
    if (isEmpty(this.statsExcludingPms)) return 0;
    let count = 0;
    this.statsExcludingPms.forEach(val => {
      if (this.inAllStream(val)) {
        count += val.count;
      }
    });
    return count;
  },

  // The user's stats, excluding PMs.
  @discourseComputed("stats.@each.isPM")
  statsExcludingPms() {
    if (isEmpty(this.stats)) return [];
    return this.stats.rejectBy("isPM");
  },

  findDetails(options) {
    const user = this;

    return PreloadStore.getAndRemove(`user_${user.get("username")}`, () => {
      const useCardRoute = options && options.forCard;

      if (options) delete options.forCard;

      const path = useCardRoute
        ? `${user.get("username")}/card.json`
        : `${user.get("username")}.json`;

      return ajax(userPath(path), { data: options });
    }).then(json => {
      if (!isEmpty(json.user.stats)) {
        json.user.stats = User.groupStats(
          json.user.stats.map(s => {
            if (s.count) s.count = parseInt(s.count, 10);
            return UserActionStat.create(s);
          })
        );
      }

      if (!isEmpty(json.user.groups)) {
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
        UserBadge.createFromJson(json).forEach(userBadge => {
          userBadgesMap[userBadge.get("id")] = userBadge;
        });
        json.user.featured_user_badges = json.user.featured_user_badge_ids.map(
          id => userBadgesMap[id]
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
      info => {
        this.setProperties(info);
      }
    );
  },

  pickAvatar(upload_id, type) {
    return ajax(userPath(`${this.username_lower}/preferences/avatar/pick`), {
      type: "PUT",
      data: { upload_id, type }
    });
  },

  selectAvatar(avatarUrl) {
    return ajax(userPath(`${this.username_lower}/preferences/avatar/select`), {
      type: "PUT",
      data: { url: avatarUrl }
    });
  },

  isAllowedToUploadAFile(type) {
    return (
      this.staff ||
      this.trust_level > 0 ||
      Discourse.SiteSettings[`newuser_max_${type}s`] > 0
    );
  },

  createInvite(email, group_names, custom_message) {
    return ajax("/invites", {
      type: "POST",
      data: { email, group_names, custom_message }
    });
  },

  generateInviteLink(email, group_names, topic_id) {
    return ajax("/invites/link", {
      type: "POST",
      data: { email, group_names, topic_id }
    });
  },

  @observes("muted_category_ids")
  updateMutedCategories() {
    this.set("mutedCategories", Category.findByIds(this.muted_category_ids));
  },

  @observes("tracked_category_ids")
  updateTrackedCategories() {
    this.set(
      "trackedCategories",
      Category.findByIds(this.tracked_category_ids)
    );
  },

  @observes("watched_category_ids")
  updateWatchedCategories() {
    this.set(
      "watchedCategories",
      Category.findByIds(this.watched_category_ids)
    );
  },

  @observes("watched_first_post_category_ids")
  updateWatchedFirstPostCategories() {
    this.set(
      "watchedFirstPostCategories",
      Category.findByIds(this.watched_first_post_category_ids)
    );
  },

  @discourseComputed("can_delete_account")
  canDeleteAccount(canDeleteAccount) {
    return !Discourse.SiteSettings.enable_sso && canDeleteAccount;
  },

  delete: function() {
    if (this.can_delete_account) {
      return ajax(userPath(this.username + ".json"), {
        type: "DELETE",
        data: { context: window.location.pathname }
      });
    } else {
      return Promise.reject(I18n.t("user.delete_yourself_not_allowed"));
    }
  },

  updateNotificationLevel(level, expiringAt) {
    return ajax(`${userPath(this.username)}/notification_level.json`, {
      type: "PUT",
      data: { notification_level: level, expiring_at: expiringAt }
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
      data: { dismissed_banner_key: bannerKey }
    });
  },

  checkEmail() {
    return ajax(userPath(`${this.username_lower}/emails.json`), {
      data: { context: window.location.pathname }
    }).then(result => {
      if (result) {
        this.setProperties({
          email: result.email,
          secondary_emails: result.secondary_emails,
          associated_accounts: result.associated_accounts
        });
      }
    });
  },

  summary() {
    // let { store } = this; would fail in tests
    const store = Discourse.__container__.lookup("service:store");

    return ajax(userPath(`${this.username_lower}/summary.json`)).then(json => {
      const summary = json.user_summary;
      const topicMap = {};
      const badgeMap = {};

      json.topics.forEach(
        t => (topicMap[t.id] = store.createRecord("topic", t))
      );
      Badge.createFromJson(json).forEach(b => (badgeMap[b.id] = b));

      summary.topics = summary.topic_ids.map(id => topicMap[id]);

      summary.replies.forEach(r => {
        r.topic = topicMap[r.topic_id];
        r.url = r.topic.urlForPostNumber(r.post_number);
        r.createdAt = new Date(r.created_at);
      });

      summary.links.forEach(l => {
        l.topic = topicMap[l.topic_id];
        l.post_url = l.topic.urlForPostNumber(l.post_number);
      });

      if (summary.badges) {
        summary.badges = summary.badges.map(ub => {
          const badge = badgeMap[ub.badge_id];
          badge.count = ub.count;
          return badge;
        });
      }

      if (summary.top_categories) {
        summary.top_categories.forEach(c => {
          if (c.parent_category_id) {
            c.parentCategory = Category.findById(c.parent_category_id);
          }
        });
      }

      return summary;
    });
  },

  canManageGroup(group) {
    return group.get("automatic")
      ? false
      : this.admin || group.get("is_group_owner");
  },

  @discourseComputed("groups.@each.title", "badges.[]")
  availableTitles() {
    let titles = [];

    (this.groups || []).forEach(group => {
      if (group.get("title")) {
        titles.push(group.get("title"));
      }
    });

    (this.badges || []).forEach(badge => {
      if (badge.get("allow_title")) {
        titles.push(badge.get("name"));
      }
    });

    return _.uniq(titles)
      .sort()
      .map(title => {
        return {
          name: Ember.Handlebars.Utils.escapeExpression(title),
          id: title
        };
      });
  },

  @discourseComputed("user_option.text_size_seq", "user_option.text_size")
  currentTextSize(serverSeq, serverSize) {
    if ($.cookie("text_size")) {
      const [cookieSize, cookieSeq] = $.cookie("text_size").split("|");
      if (cookieSeq >= serverSeq) {
        return cookieSize;
      }
    }
    return serverSize;
  },

  updateTextSizeCookie(newSize) {
    if (newSize) {
      const seq = this.get("user_option.text_size_seq");
      $.cookie("text_size", `${newSize}|${seq}`, {
        path: "/",
        expires: 9999
      });
    } else {
      $.removeCookie("text_size", { path: "/", expires: 1 });
    }
  },

  @discourseComputed("second_factor_enabled", "staff")
  enforcedSecondFactor(secondFactorEnabled, staff) {
    const enforce = Discourse.SiteSettings.enforce_second_factor;
    return (
      !secondFactorEnabled &&
      (enforce === "all" || (enforce === "staff" && staff))
    );
  }
});

User.reopenClass(Singleton, {
  // Find a `User` for a given username.
  findByUsername(username, options) {
    const user = User.create({ username: username });
    return user.findDetails(options);
  },

  // TODO: Use app.register and junk Singleton
  createCurrent() {
    const userJson = PreloadStore.get("currentUser");

    if (userJson && userJson.primary_group_id) {
      const primaryGroup = userJson.groups.find(
        group => group.id === userJson.primary_group_id
      );
      if (primaryGroup) {
        userJson.primary_group_name = primaryGroup.name;
      }
    }

    if (userJson) {
      const store = Discourse.__container__.lookup("service:store");
      return store.createRecord("user", userJson);
    }
    return null;
  },

  resetCurrent(user) {
    this._super(user);
    Discourse.currentUser = user;
  },

  checkUsername(username, email, for_user_id) {
    return ajax(userPath("check_username"), {
      data: { username, email, for_user_id }
    });
  },

  groupStats(stats) {
    const responses = UserActionStat.create({
      count: 0,
      action_type: UserAction.TYPES.replies
    });

    stats.filterBy("isResponse").forEach(stat => {
      responses.set("count", responses.get("count") + stat.get("count"));
    });

    const result = Ember.A();
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
    return ajax(userPath(), {
      data: {
        name: attrs.accountName,
        email: attrs.accountEmail,
        password: attrs.accountPassword,
        username: attrs.accountUsername,
        password_confirmation: attrs.accountPasswordConfirm,
        challenge: attrs.accountChallenge,
        user_fields: attrs.userFields,
        timezone: moment.tz.guess()
      },
      type: "POST"
    });
  }
});

let warned = false;
Object.defineProperty(Discourse, "User", {
  get() {
    if (!warned) {
      deprecated("Import the User class instead of using User", {
        since: "2.4.0",
        dropFrom: "2.6.0"
      });
      warned = true;
    }
    return User;
  }
});

export default User;
