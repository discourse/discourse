import computed from "ember-addons/ember-computed-decorators";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Ember.Component.extend({
  elementId: "suggested-topics",
  classNames: ["suggested-topics"],

  @computed("topic")
  suggestedTitle(topic) {
    const href = this.currentUser && this.currentUser.pmPath(topic);
    return topic.get("isPrivateMessage") && href
      ? `<a href="${href}">${iconHTML("envelope", {
          class: "private-message-glyph"
        })}</a><span>${I18n.t("suggested_topics.pm_title")}</span>`
      : I18n.t("suggested_topics.title");
  },

  @computed("topic", "topicTrackingState.messageCount")
  browseMoreMessage(topic) {
    // TODO decide what to show for pms
    if (topic.get("isPrivateMessage")) {
      return;
    }

    const opts = {
      latestLink: `<a href="${Discourse.getURL("/latest")}">${I18n.t(
        "topic.view_latest_topics"
      )}</a>`
    };
    let category = topic.get("category");

    if (
      category &&
      Ember.get(category, "id") ===
        Discourse.Site.currentProp("uncategorized_category_id")
    ) {
      category = null;
    }

    if (category) {
      opts.catLink = categoryBadgeHTML(category);
    } else {
      opts.catLink =
        '<a href="' +
        Discourse.getURL("/categories") +
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
