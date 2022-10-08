import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import I18n from "I18n";
import LivePostCounts from "discourse/models/live-post-counts";
import { alias } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";

export default Component.extend({
  classNameBindings: ["hidden:hidden", ":create-topics-notice"],

  enabled: false,
  router: service(),

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
      this.site.get("categories").forEach((c) => {
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

  @discourseComputed(
    "siteSettings.show_create_topics_notice",
    "router.currentRouteName"
  )
  shouldSee(showCreateTopicsNotice, currentRouteName) {
    return (
      this.currentUser?.get("admin") &&
      showCreateTopicsNotice &&
      !this.site.get("wizard_required") &&
      !currentRouteName.startsWith("wizard")
    );
  },

  @discourseComputed(
    "enabled",
    "shouldSee",
    "publicTopicCount",
    "publicPostCount"
  )
  hidden(enabled, shouldSee, publicTopicCount, publicPostCount) {
    return (
      !enabled ||
      !shouldSee ||
      publicTopicCount == null ||
      publicPostCount == null
    );
  },

  @discourseComputed(
    "publicTopicCount",
    "publicPostCount",
    "topicTrackingState.incomingCount"
  )
  message(publicTopicCount, publicPostCount) {
    let msg = null;

    if (
      publicTopicCount < this.requiredTopics &&
      publicPostCount < this.requiredPosts
    ) {
      msg = "too_few_topics_and_posts_notice_MF";
    } else if (publicTopicCount < this.requiredTopics) {
      msg = "too_few_topics_notice_MF";
    } else {
      msg = "too_few_posts_notice_MF";
    }

    return htmlSafe(
      I18n.messageFormat(msg, {
        requiredTopics: this.requiredTopics,
        requiredPosts: this.requiredPosts,
        currentTopics: publicTopicCount,
        currentPosts: publicPostCount,
      })
    );
  },

  @observes("topicTrackingState.incomingCount")
  fetchLiveStats() {
    if (!this.enabled) {
      return;
    }

    LivePostCounts.find().then((stats) => {
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
  },
});
