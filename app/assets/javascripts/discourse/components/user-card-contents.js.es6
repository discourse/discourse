import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import User from "discourse/models/user";
import { propertyNotEqual, setting } from "discourse/lib/computed";
import { durationTiny } from "discourse/lib/formatter";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import CardContentsBase from "discourse/mixins/card-contents-base";
import CleansUp from "discourse/mixins/cleans-up";
import { prioritizeNameInUx } from "discourse/lib/settings";

export default Ember.Component.extend(
  CardContentsBase,
  CanCheckEmails,
  CleansUp,
  {
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

    postStream: Ember.computed.alias("topic.postStream"),
    enoughPostsForFiltering: Ember.computed.gte("topicPostCount", 2),
    showFilter: Ember.computed.and(
      "viewingTopic",
      "postStream.hasNoFilters",
      "enoughPostsForFiltering"
    ),
    showName: propertyNotEqual("user.name", "user.username"),
    hasUserFilters: Ember.computed.gt("postStream.userFilters.length", 0),
    showMoreBadges: Ember.computed.gt("moreBadgesCount", 0),
    showDelete: Ember.computed.and(
      "viewingAdmin",
      "showName",
      "user.canBeDeleted"
    ),
    linkWebsite: Ember.computed.not("user.isBasic"),
    hasLocationOrWebsite: Ember.computed.or(
      "user.location",
      "user.website_name"
    ),
    isSuspendedOrHasBio: Ember.computed.or(
      "user.suspend_reason",
      "user.bio_cooked"
    ),
    showCheckEmail: Ember.computed.and("user.staged", "canCheckEmails"),

    user: null,

    // If inside a topic
    topicPostCount: null,

    @computed("user.staff")
    staff: isStaff => (isStaff ? "staff" : ""),

    @computed("user.trust_level")
    newUser: trustLevel => (trustLevel === 0 ? "new-user" : ""),

    @computed("user.name")
    nameFirst(name) {
      return prioritizeNameInUx(name, this.siteSettings);
    },

    @computed("username")
    usernameClass: username => (username ? `user-card-${username}` : ""),

    @computed("username", "topicPostCount")
    togglePostsLabel(username, count) {
      return I18n.t("topic.filter_to", { username, count });
    },

    @computed("user.user_fields.@each.value")
    publicUserFields() {
      const siteUserFields = this.site.get("user_fields");
      if (!Ember.isEmpty(siteUserFields)) {
        const userFields = this.get("user.user_fields");
        return siteUserFields
          .filterBy("show_on_user_card", true)
          .sortBy("position")
          .map(field => {
            Ember.set(field, "dasherized_name", field.get("name").dasherize());
            const value = userFields ? userFields[field.get("id")] : null;
            return Ember.isEmpty(value)
              ? null
              : Ember.Object.create({ value, field });
          })
          .compact();
      }
    },

    @computed("user.trust_level")
    removeNoFollow(trustLevel) {
      return trustLevel > 2 && !this.siteSettings.tl3_links_no_follow;
    },

    @computed("user.badge_count", "user.featured_user_badges.length")
    moreBadgesCount: (badgeCount, badgeLength) => badgeCount - badgeLength,

    @computed("user.time_read", "user.recent_time_read")
    showRecentTimeRead(timeRead, recentTimeRead) {
      return timeRead !== recentTimeRead && recentTimeRead !== 0;
    },

    @computed("user.recent_time_read")
    recentTimeRead(recentTimeReadSeconds) {
      return durationTiny(recentTimeReadSeconds);
    },

    @computed("showRecentTimeRead", "user.time_read", "recentTimeRead")
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
      const bg = Ember.isEmpty(url)
        ? ""
        : `url(${Discourse.getURLWithCDN(url)})`;
      thisElem.style.backgroundImage = bg;
    },

    _showCallback(username, $target) {
      this._positionCard($target);
      this.setProperties({ visible: true, loading: true });

      const args = { stats: false };
      args.include_post_count_for = this.get("topic.id");
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

        Ember.getOwner(this)
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
  }
);
