import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { computed, get } from "@ember/object";
import Component from "@ember/component";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import Site from "discourse/models/site";

export default Component.extend({
  tagName: "",

  suggestedTitleLabel: computed("topic", function() {
    const href = this.currentUser && this.currentUser.pmPath(this.topic);
    if (this.topic.get("isPrivateMessage") && href) {
      return "suggested_topics.pm_title";
    } else {
      return "suggested_topics.title";
    }
  }),

  @discourseComputed("topic", "topicTrackingState.messageCount")
  browseMoreMessage(topic) {
    // TODO decide what to show for pms
    if (topic.get("isPrivateMessage")) {
      return;
    }

    const opts = {
      latestLink: `<a href="${getURL("/latest")}">${I18n.t(
        "topic.view_latest_topics"
      )}</a>`
    };
    let category = topic.get("category");

    if (
      category &&
      get(category, "id") === Site.currentProp("uncategorized_category_id")
    ) {
      category = null;
    }

    if (category) {
      opts.catLink = categoryBadgeHTML(category);
    } else {
      opts.catLink =
        '<a href="' +
        getURL("/categories") +
        '">' +
        I18n.t("topic.browse_all_categories") +
        "</a>";
    }

    const unreadTopics = this.topicTrackingState.countUnread();
    const newTopics = this.currentUser ? this.topicTrackingState.countNew() : 0;

    if (newTopics + unreadTopics > 0) {
      const hasBoth = unreadTopics > 0 && newTopics > 0;

      return I18n.messageFormat("topic.read_more_MF", {
        BOTH: hasBoth,
        UNREAD: unreadTopics,
        NEW: newTopics,
        CATEGORY: category ? true : false,
        latestLink: opts.latestLink,
        catLink: opts.catLink,
        basePath: ""
      });
    } else if (category) {
      return I18n.t("topic.read_more_in_category", opts);
    } else {
      return I18n.t("topic.read_more", opts);
    }
  }
});
