import computed from "ember-addons/ember-computed-decorators";
import { observes } from "ember-addons/ember-computed-decorators";
import LivePostCounts from "discourse/models/live-post-counts";

export default Ember.Component.extend({
  classNameBindings: ["hidden:hidden", ":create-topics-notice"],

  enabled: false,

  publicTopicCount: null,
  publicPostCount: null,

  requiredTopics: 5,
  requiredPosts: Ember.computed.alias("siteSettings.tl1_requires_read_posts"),

  init() {
    this._super(...arguments);
    if (this.get("shouldSee")) {
      let topicCount = 0,
        postCount = 0;

      // Use data we already have before fetching live stats
      this.site.get("categories").forEach(c => {
        if (!c.get("read_restricted")) {
          topicCount += c.get("topic_count");
          postCount += c.get("post_count");
        }
      });

      if (
        topicCount < this.get("requiredTopics") ||
        postCount < this.get("requiredPosts")
      ) {
        this.set("enabled", true);
        this.fetchLiveStats();
      }
    }
  },

  @computed()
  shouldSee() {
    const user = this.currentUser;
    return (
      user &&
      user.get("admin") &&
      this.siteSettings.show_create_topics_notice &&
      !this.site.get("wizard_required")
    );
  },

  @computed("enabled", "shouldSee", "publicTopicCount", "publicPostCount")
  hidden() {
    return (
      !this.get("enabled") ||
      !this.get("shouldSee") ||
      this.get("publicTopicCount") == null ||
      this.get("publicPostCount") == null
    );
  },

  @computed(
    "publicTopicCount",
    "publicPostCount",
    "topicTrackingState.incomingCount"
  )
  message() {
    var msg = null;

    if (
      this.get("publicTopicCount") < this.get("requiredTopics") &&
      this.get("publicPostCount") < this.get("requiredPosts")
    ) {
      msg = "too_few_topics_and_posts_notice";
    } else if (this.get("publicTopicCount") < this.get("requiredTopics")) {
      msg = "too_few_topics_notice";
    } else {
      msg = "too_few_posts_notice";
    }

    return new Handlebars.SafeString(
      I18n.t(msg, {
        requiredTopics: this.get("requiredTopics"),
        requiredPosts: this.get("requiredPosts"),
        currentTopics: this.get("publicTopicCount"),
        currentPosts: this.get("publicPostCount")
      })
    );
  },

  @observes("topicTrackingState.incomingCount")
  fetchLiveStats() {
    if (!this.get("enabled")) {
      return;
    }

    LivePostCounts.find().then(stats => {
      if (stats) {
        this.set("publicTopicCount", stats.get("public_topic_count"));
        this.set("publicPostCount", stats.get("public_post_count"));
        if (
          this.get("publicTopicCount") >= this.get("requiredTopics") &&
          this.get("publicPostCount") >= this.get("requiredPosts")
        ) {
          this.set("enabled", false); // No more checks
        }
      }
    });
  }
});
