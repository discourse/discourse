import { isEmpty } from "@ember/utils";
import { alias, gte, and, gt, not, or } from "@ember/object/computed";
import EmberObject from "@ember/object";
import Component from "@ember/component";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import User from "discourse/models/user";
import { propertyNotEqual, setting } from "discourse/lib/computed";
import { durationTiny } from "discourse/lib/formatter";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import CardContentsBase from "discourse/mixins/card-contents-base";
import CleansUp from "discourse/mixins/cleans-up";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { set } from "@ember/object";
import { getOwner } from "@ember/application";

export default Component.extend(CardContentsBase, CanCheckEmails, CleansUp, {
  elementId: "user-card",
  triggeringLinkClass: "mention",
  classNameBindings: [
    "visible:show",
    "showBadges",
    "user.card_background::no-bg",
    "isFixed:fixed",
    "usernameClass"
  ],
  allowBackgrounds: setting("allow_profile_backgrounds"),
  showBadges: setting("enable_badges"),

  postStream: alias("topic.postStream"),
  enoughPostsForFiltering: gte("topicPostCount", 2),
  showFilter: and(
    "viewingTopic",
    "postStream.hasNoFilters",
    "enoughPostsForFiltering"
  ),
  showName: propertyNotEqual("user.name", "user.username"),
  hasUserFilters: gt("postStream.userFilters.length", 0),
  showMoreBadges: gt("moreBadgesCount", 0),
  showDelete: and("viewingAdmin", "showName", "user.canBeDeleted"),
  linkWebsite: not("user.isBasic"),
  hasLocationOrWebsite: or("user.location", "user.website_name"),
  isSuspendedOrHasBio: or("user.suspend_reason", "user.bio_cooked"),
  showCheckEmail: and("user.staged", "canCheckEmails"),

  user: null,

  // If inside a topic
  topicPostCount: null,

  showFeaturedTopic: and(
    "user.featured_topic",
    "siteSettings.allow_featured_topic_on_user_profiles"
  ),

  @discourseComputed("user.staff")
  staff: isStaff => (isStaff ? "staff" : ""),

  @discourseComputed("user.trust_level")
  newUser: trustLevel => (trustLevel === 0 ? "new-user" : ""),

  @discourseComputed("user.name")
  nameFirst(name) {
    return prioritizeNameInUx(name, this.siteSettings);
  },

  @discourseComputed("username")
  usernameClass: username => (username ? `user-card-${username}` : ""),

  @discourseComputed("username", "topicPostCount")
  togglePostsLabel(username, count) {
    return I18n.t("topic.filter_to", { username, count });
  },

  @discourseComputed("user.user_fields.@each.value")
  publicUserFields() {
    const siteUserFields = this.site.get("user_fields");
    if (!isEmpty(siteUserFields)) {
      const userFields = this.get("user.user_fields");
      return siteUserFields
        .filterBy("show_on_user_card", true)
        .sortBy("position")
        .map(field => {
          set(field, "dasherized_name", field.get("name").dasherize());
          const value = userFields ? userFields[field.get("id")] : null;
          return isEmpty(value) ? null : EmberObject.create({ value, field });
        })
        .compact();
    }
  },

  @discourseComputed("user.trust_level")
  removeNoFollow(trustLevel) {
    return trustLevel > 2 && !this.siteSettings.tl3_links_no_follow;
  },

  @discourseComputed("user.badge_count", "user.featured_user_badges.length")
  moreBadgesCount: (badgeCount, badgeLength) => badgeCount - badgeLength,

  @discourseComputed("user.time_read", "user.recent_time_read")
  showRecentTimeRead(timeRead, recentTimeRead) {
    return timeRead !== recentTimeRead && recentTimeRead !== 0;
  },

  @discourseComputed("user.recent_time_read")
  recentTimeRead(recentTimeReadSeconds) {
    return durationTiny(recentTimeReadSeconds);
  },

  @discourseComputed("showRecentTimeRead", "user.time_read", "recentTimeRead")
  timeReadTooltip(showRecent, timeRead, recentTimeRead) {
    if (showRecent) {
      return I18n.t("time_read_recently_tooltip", {
        time_read: durationTiny(timeRead),
        recent_time_read: recentTimeRead
      });
    } else {
      return I18n.t("time_read_tooltip", {
        time_read: durationTiny(timeRead)
      });
    }
  },

  @observes("user.card_background_upload_url")
  addBackground() {
    if (!this.allowBackgrounds) {
      return;
    }

    const thisElem = this.element;
    if (!thisElem) {
      return;
    }

    const url = this.get("user.card_background_upload_url");
    const bg = isEmpty(url) ? "" : `url(${Discourse.getURLWithCDN(url)})`;
    thisElem.style.backgroundImage = bg;
  },

  _showCallback(username, $target) {
    this._positionCard($target);
    this.setProperties({ visible: true, loading: true });

    const args = {
      forCard: this.siteSettings.enable_new_user_card_route,
      include_post_count_for: this.get("topic.id")
    };

    User.findByUsername(username, args)
      .then(user => {
        if (user.topic_post_count) {
          this.set(
            "topicPostCount",
            user.topic_post_count[args.include_post_count_for]
          );
        }
        this.setProperties({ user });
      })
      .catch(() => this._close())
      .finally(() => this.set("loading", null));
  },

  _close() {
    this._super(...arguments);

    this.setProperties({
      user: null,
      topicPostCount: null
    });
  },

  cleanUp() {
    this._close();
  },

  actions: {
    close() {
      this._close();
    },

    composePM(user, post) {
      this._close();

      getOwner(this)
        .lookup("router:main")
        .send("composePrivateMessage", user, post);
    },

    cancelFilter() {
      const postStream = this.postStream;
      postStream.cancelFilter();
      postStream.refresh();
      this._close();
    },

    togglePosts() {
      this.togglePosts(this.user);
      this._close();
    },

    deleteUser() {
      this.user.delete();
      this._close();
    },

    showUser(username) {
      this.showUser(username);
      this._close();
    },

    checkEmail(user) {
      user.checkEmail();
    }
  }
});
