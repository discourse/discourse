import discourseComputed from "discourse-common/utils/decorators";
import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import { observes } from "discourse-common/utils/decorators";
import LivePostCounts from "discourse/models/live-post-counts";

export default Component.extend({
  classNameBindings: ["hidden:hidden", ":create-topics-notice"],

  enabled: false,

  publicTopicCount: null,
  publicPostCount: null,

  requiredTopics: 5,
  requiredPosts: alias("siteSettings.tl1_requires_read_posts"),

  init() {
    this._super(...arguments);
    if (this.shouldSee) {
      let topicCount = 0,
        postCount = 0;

      // Use data we already have before fetching live stats
      this.site.get("categories").forEach(c => {
        if (!c.get("read_restricted")) {
          topicCount += c.get("topic_count");
          postCount += c.get("post_count");
        }
      });

      if (topicCount < this.requiredTopics || postCount < this.requiredPosts) {
        this.set("enabled", true);
        this.fetchLiveStats();
      }
    }
  },

  @discourseComputed()
  shouldSee() {
    const user = this.currentUser;
    return (
      user &&
      user.get("admin") &&
      this.siteSettings.show_create_topics_notice &&
      !this.site.get("wizard_required")
    );
  },

  @discourseComputed(
    "enabled",
    "shouldSee",
    "publicTopicCount",
    "publicPostCount"
  )
  hidden() {
    return (
      !this.enabled ||
      !this.shouldSee ||
      this.publicTopicCount == null ||
      this.publicPostCount == null
    );
  },

  @discourseComputed(
    "publicTopicCount",
    "publicPostCount",
    "topicTrackingState.incomingCount"
  )
  message() {
    var msg = null;

    if (
      this.publicTopicCount < this.requiredTopics &&
      this.publicPostCount < this.requiredPosts
    ) {
      msg = "too_few_topics_and_posts_notice";
    } else if (this.publicTopicCount < this.requiredTopics) {
      msg = "too_few_topics_notice";
    } else {
      msg = "too_few_posts_notice";
    }

    return new Handlebars.SafeString(
      I18n.t(msg, {
        requiredTopics: this.requiredTopics,
        requiredPosts: this.requiredPosts,
        currentTopics: this.publicTopicCount,
        currentPosts: this.publicPostCount
      })
    );
  },

  @observes("topicTrackingState.incomingCount")
  fetchLiveStats() {
    if (!this.enabled) {
      return;
    }

    LivePostCounts.find().then(stats => {
      if (stats) {
        this.set("publicTopicCount", stats.get("public_topic_count"));
        this.set("publicPostCount", stats.get("public_post_count"));
        if (
          this.publicTopicCount >= this.requiredTopics &&
          this.publicPostCount >= this.requiredPosts
        ) {
          this.set("enabled", false); // No more checks
        }
      }
    });
  }
});
