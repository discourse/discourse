import EmberObject, { action, computed, set } from "@ember/object";
import { alias, and, gt, gte, not, or } from "@ember/object/computed";
import { dasherize } from "@ember/string";
import { isEmpty } from "@ember/utils";
import {
  attributeBindings,
  classNameBindings,
  classNames,
} from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import CardContentsBase from "discourse/components/card-contents-base";
import { setting } from "discourse/lib/computed";
import { durationTiny } from "discourse/lib/formatter";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import CleansUp from "discourse/mixins/cleans-up";
import User from "discourse/models/user";
import { getURLWithCDN } from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

@classNames("user-card")
@classNameBindings(
  "visible:show",
  "showBadges",
  "user.card_background_upload_url::no-bg",
  "isFixed:fixed",
  "usernameClass",
  "primaryGroup"
)
@attributeBindings("ariaLabel:aria-label")
export default class UserCardContents extends CardContentsBase.extend(
  CanCheckEmails,
  CleansUp
) {
  elementId = "user-card";
  avatarSelector = "[data-user-card]";
  avatarDataAttrKey = "userCard";
  mentionSelector = "a.mention";
  ariaLabel = I18n.t("user.card");

  @setting("allow_profile_backgrounds") allowBackgrounds;
  @setting("enable_badges") showBadges;
  @setting("display_local_time_in_user_card") showUserLocalTime;

  @alias("topic.postStream") postStream;

  @gte("topicPostCount", 2) enoughPostsForFiltering;

  @and("viewingTopic", "postStream.hasNoFilters", "enoughPostsForFiltering")
  showFilter;

  @gt("postStream.userFilters.length", 0) hasUserFilters;
  @gt("moreBadgesCount", 0) showMoreBadges;
  @and("viewingAdmin", "showName", "user.canBeDeleted") showDelete;
  @not("user.isBasic") linkWebsite;
  @or("user.suspend_reason", "user.bio_excerpt") isSuspendedOrHasBio;
  @and("user.staged", "canCheckEmails") showCheckEmail;

  user = null;

  // If inside a topic
  topicPostCount = null;

  @and(
    "user.featured_topic",
    "siteSettings.allow_featured_topic_on_user_profiles"
  )
  showFeaturedTopic;

  @computed("user.name", "user.username")
  get showName() {
    return this.user.name !== this.user.username;
  }

  @discourseComputed("user")
  hasLocaleOrWebsite(user) {
    return user.location || user.website_name || this.userTimezone;
  }

  @discourseComputed("user.status")
  hasStatus() {
    return this.siteSettings.enable_user_status && this.user.status;
  }

  @discourseComputed("user.status.emoji")
  userStatusEmoji(emoji) {
    return emojiUnescape(escapeExpression(`:${emoji}:`));
  }

  @discourseComputed("user.staff")
  staff(isStaff) {
    return isStaff ? "staff" : "";
  }

  @discourseComputed("user.trust_level")
  newUser(trustLevel) {
    return trustLevel === 0 ? "new-user" : "";
  }

  @discourseComputed("user.name")
  nameFirst(name) {
    return prioritizeNameInUx(name);
  }

  @discourseComputed("user")
  userTimezone(user) {
    if (!this.showUserLocalTime) {
      return;
    }
    return user.get("user_option.timezone");
  }

  @discourseComputed("userTimezone")
  formattedUserLocalTime(timezone) {
    return moment.tz(timezone).format(I18n.t("dates.time"));
  }

  @discourseComputed("username")
  usernameClass(username) {
    return username ? `user-card-${username}` : "";
  }

  @discourseComputed("username", "topicPostCount")
  filterPostsLabel(username, count) {
    return I18n.t("topic.filter_to", { username, count });
  }

  @discourseComputed("user.user_fields.@each.value")
  publicUserFields() {
    const siteUserFields = this.site.get("user_fields");
    if (!isEmpty(siteUserFields)) {
      const userFields = this.get("user.user_fields");
      return siteUserFields
        .filterBy("show_on_user_card", true)
        .sortBy("position")
        .map((field) => {
          set(field, "dasherized_name", dasherize(field.get("name")));
          const value = userFields ? userFields[field.get("id")] : null;
          return isEmpty(value) ? null : EmberObject.create({ value, field });
        })
        .compact();
    }
  }

  @discourseComputed("user.trust_level")
  removeNoFollow(trustLevel) {
    return trustLevel > 2 && !this.siteSettings.tl3_links_no_follow;
  }

  @discourseComputed("user.badge_count", "user.featured_user_badges.length")
  moreBadgesCount(badgeCount, badgeLength) {
    return badgeCount - badgeLength;
  }

  @discourseComputed("user.time_read", "user.recent_time_read")
  showRecentTimeRead(timeRead, recentTimeRead) {
    return timeRead !== recentTimeRead && recentTimeRead !== 0;
  }

  @discourseComputed("user.recent_time_read")
  recentTimeRead(recentTimeReadSeconds) {
    return durationTiny(recentTimeReadSeconds);
  }

  @discourseComputed("showRecentTimeRead", "user.time_read", "recentTimeRead")
  timeReadTooltip(showRecent, timeRead, recentTimeRead) {
    if (showRecent) {
      return I18n.t("time_read_recently_tooltip", {
        time_read: durationTiny(timeRead),
        recent_time_read: recentTimeRead,
      });
    } else {
      return I18n.t("time_read_tooltip", {
        time_read: durationTiny(timeRead),
      });
    }
  }

  @observes("user.card_background_upload_url")
  addBackground() {
    if (!this.allowBackgrounds) {
      return;
    }

    if (!this.element) {
      return;
    }

    const url = this.get("user.card_background_upload_url");
    const bg = isEmpty(url) ? "" : `url(${getURLWithCDN(url)})`;
    this.element.style.backgroundImage = bg;
  }

  @discourseComputed("user.primary_group_name")
  primaryGroup(primaryGroup) {
    return `group-${primaryGroup}`;
  }

  @discourseComputed("user.profile_hidden", "user.inactive")
  contentHidden(profileHidden, inactive) {
    return profileHidden || inactive;
  }

  async _showCallback(username) {
    this.setProperties({ visible: true, loading: true });

    const args = {
      forCard: true,
      include_post_count_for: this.get("topic.id"),
    };

    try {
      const user = await User.findByUsername(username, args);

      if (user.topic_post_count) {
        this.set(
          "topicPostCount",
          user.topic_post_count[args.include_post_count_for]
        );
      }
      this.setProperties({ user });
      this.user.statusManager.trackStatus();

      return user;
    } catch {
      this._close();
    } finally {
      this.set("loading", null);
    }
  }

  _close() {
    this.user?.statusManager.stopTrackingStatus();

    this.setProperties({
      user: null,
      topicPostCount: null,
    });

    super._close(...arguments);
  }

  cleanUp() {
    this._close();
  }

  @action
  refreshRoute(value) {
    this.router.transitionTo({ queryParams: { name: value } });
  }

  @action
  handleShowUser(event) {
    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    // Invokes `showUser` argument. Convert to `this.args.showUser` when
    // refactoring this to a glimmer component.
    this.showUser(this.user);
    this._close();
  }

  @action
  close() {
    this._close();
  }

  @action
  composePM(user, post) {
    this._close();
    this.composePrivateMessage(user, post);
  }

  @action
  cancelFilter() {
    this.postStream.cancelFilter();
    this.postStream.refresh();
    this._close();
  }

  @action
  handleFilterPosts() {
    this.filterPosts(this.user);
    this._close();
  }

  @action
  deleteUser() {
    this.user.delete();
    this._close();
  }

  @action
  checkEmail(user) {
    user.checkEmail();
  }
}
